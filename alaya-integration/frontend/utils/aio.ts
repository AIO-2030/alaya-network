/**
 * @fileoverview AIO Integration Helper Functions
 * @description Minimal TypeScript helpers for interacting with Interaction contract
 * Supports both wagmi/viem and ethers v6
 */

// Type definitions (will work with viem and ethers when installed)
export type Address = `0x${string}` | string;
export type BytesLike = string | Uint8Array;
export type BigNumberish = string | number | bigint;

// ============================================================================
// Types
// ============================================================================

/**
 * Provider interface that works with both viem and ethers
 */
export interface ProviderLike {
  // Viem-style (wagmi)
  request?: (args: { method: string; params?: any[] }) => Promise<any>;
  chain?: any; // Chain info for viem
  
  // Ethers v6 style
  call?: (transaction: { to: string; data: string }) => Promise<string>;
  sendTransaction?: (transaction: { to: string; data: string; value?: bigint }) => Promise<{ hash: string }>;
  getSigner?: (address?: string) => Promise<any> | any; // Ethers signer
  getAddress?: () => Promise<string> | string; // For signers that have address
  
  // Common
  getCode?: (address: string) => Promise<string>;
}

export interface Config {
  feeWei: bigint;
  feeDistributor: Address;
  allowlistEnabled: boolean;
}

export interface InteractOptions {
  /** Interaction contract address */
  interactionAddress: Address;
  /** User's account address */
  account: Address;
  /** Action string (e.g., "send_pixelmug", "aio_rpc_call") */
  action: string;
  /** Metadata as JSON bytes (will be encoded) */
  meta: BytesLike;
  /** ETH value for interact() (must be >= feeWei) */
  value?: BigNumberish;
}

export interface Interact20Options extends Omit<InteractOptions, "value"> {
  /** ERC20 token address */
  token: Address;
  /** Amount of tokens to pay as fee */
  amount: BigNumberish;
  /** Interaction contract address (needed for approval) */
  interactionAddress: Address;
}

// ============================================================================
// ABI Imports (minimal ABIs)
// ============================================================================

import InteractionABI from "../../abi/Interaction.json";
import FeeDistributorABI from "../../abi/FeeDistributor.json";
import AIOERC20ABI from "../../abi/AIOERC20.json";

// ============================================================================
// Helper: Detect Provider Type
// ============================================================================

function isViemProvider(provider: any): boolean {
  return typeof provider.request === "function";
}

function isEthersProvider(provider: any): boolean {
  return typeof provider.call === "function" || typeof provider.getAddress === "function";
}

// ============================================================================
// Helper: Encode Meta (JSON to bytes)
// ============================================================================

/**
 * Encodes JSON object to bytes (BytesLike)
 * @param meta JSON object or already encoded bytes
 */
export function encodeMeta(meta: object | BytesLike): BytesLike {
  if (typeof meta === "string" && meta.startsWith("0x")) {
    return meta; // Already encoded
  }
  if (typeof meta === "object") {
    return `0x${Buffer.from(JSON.stringify(meta)).toString("hex")}`;
  }
  throw new Error("Invalid meta: must be object or hex string");
}

// ============================================================================
// Global Configuration
// ============================================================================

/**
 * Global interaction contract address (can be set once)
 * @example
 * setInteractionAddress("0x...");
 */
let globalInteractionAddress: Address | null = null;

/**
 * Sets the global interaction contract address
 * @param address Interaction contract address
 */
export function setInteractionAddress(address: Address): void {
  globalInteractionAddress = address;
}

/**
 * Gets the global interaction contract address
 * @returns Interaction contract address or null
 */
export function getInteractionAddress(): Address | null {
  return globalInteractionAddress;
}

// ============================================================================
// Core Functions
// ============================================================================

/**
 * Gets configuration from Interaction contract
 * @param provider Provider instance (viem or ethers)
 * @param interactionAddress Optional interaction contract address (uses global if not provided)
 * @returns Configuration object with feeWei and feeDistributor address
 */
export async function getConfig(
  provider: ProviderLike,
  interactionAddress?: Address
): Promise<{ feeWei: bigint; feeDistributor: Address }> {
  const address = interactionAddress || globalInteractionAddress;
  if (!address) {
    throw new Error("Interaction contract address is required. Either pass it as parameter or set it globally using setInteractionAddress()");
  }
  try {
    if (isViemProvider(provider)) {
      // Viem/wagmi path
      const { createPublicClient, http } = await import("viem");
      const publicClient = createPublicClient({
        transport: http(),
        // @ts-ignore - provider might have chain info
        chain: provider.chain || undefined,
      });

      const result = await publicClient.readContract({
        address: interactionAddress,
        abi: InteractionABI,
        functionName: "getConfig",
      });

      return {
        feeWei: result[0] as bigint,
        feeDistributor: result[1] as Address,
      };
    } else {
      // Ethers v6 path
      const { Contract } = await import("ethers");
      const contract = new Contract(address, InteractionABI, provider);
      const [feeWei, feeDistributor] = await contract.getConfig();

      return {
        feeWei: BigInt(feeWei.toString()),
        feeDistributor: feeDistributor as Address,
      };
    }
  } catch (error: any) {
    throw new Error(`获取配置失败: ${error.message || error}`);
  }
}

/**
 * Records an interaction with ETH fee payment (simplified signature)
 * @param provider Provider instance
 * @param action Action string (e.g., "send_pixelmug", "aio_rpc_call")
 * @param meta Metadata as JSON bytes or object (will be encoded)
 * @param value ETH value (must be >= feeWei)
 * @param options Optional: interactionAddress, account (if not provided, will try to infer from provider)
 * @returns Transaction hash
 */
export async function interact(
  provider: ProviderLike,
  action: string,
  meta: BytesLike,
  value: BigNumberish,
  options?: { interactionAddress?: Address; account?: Address }
): Promise<`0x${string}`>;

/**
 * Records an interaction with ETH fee payment (full options)
 * @param provider Provider instance
 * @param options Interaction options
 * @returns Transaction hash
 */
export async function interact(
  provider: ProviderLike,
  options: InteractOptions
): Promise<`0x${string}`>;

/**
 * Records an interaction with ETH fee payment
 * @param provider Provider instance
 * @param actionOrOptions Action string or full options object
 * @param meta Metadata (if using simplified signature)
 * @param value ETH value (if using simplified signature)
 * @param options Optional options (if using simplified signature)
 * @returns Transaction hash
 */
export async function interact(
  provider: ProviderLike,
  actionOrOptions: string | InteractOptions,
  meta?: BytesLike,
  value?: BigNumberish,
  options?: { interactionAddress?: Address; account?: Address }
): Promise<`0x${string}`> {
  // Handle function overload: detect if first param is options object
  let interactionAddress: Address;
  let account: Address;
  let action: string;
  let finalMeta: BytesLike;
  let finalValue: BigNumberish;

  if (typeof actionOrOptions === "object") {
    // Full options signature
    const opts = actionOrOptions as InteractOptions;
    interactionAddress = opts.interactionAddress;
    account = opts.account;
    action = opts.action;
    finalMeta = opts.meta;
    finalValue = opts.value || "0";
  } else {
    // Simplified signature
    action = actionOrOptions;
    finalMeta = meta!;
    finalValue = value!;
    interactionAddress = options?.interactionAddress || globalInteractionAddress || "";
    account = options?.account || "";

    if (!interactionAddress) {
      throw new Error("Interaction contract address is required. Either pass it in options or set it globally using setInteractionAddress()");
    }
    if (!account) {
      // Try to get account from provider (for ethers signers)
      if (typeof provider.getAddress === "function") {
        account = await provider.getAddress();
      } else {
        throw new Error("Account address is required. Please provide it in options or use a signer that has getAddress()");
      }
    }
  }

  // Encode meta if needed
  const encodedMeta = encodeMeta(finalMeta);

  // Get config to validate fee (outside try to use in catch)
  let feeWei: bigint;
  try {
    const config = await getConfig(provider, interactionAddress);
    feeWei = config.feeWei;
  } catch (error: any) {
    throw new Error(`获取配置失败: ${error.message || error}`);
  }

  const valueBigInt = typeof finalValue === "bigint" ? finalValue : BigInt(finalValue?.toString() || "0");

  // Validate fee
  if (valueBigInt < feeWei) {
    throw new Error(
      `费用不足：需要至少 ${feeWei.toString()} wei (约 ${(Number(feeWei) / 1e18).toFixed(6)} ETH)`
    );
  }

  try {
    if (isViemProvider(provider)) {
      // Viem/wagmi path
      const { encodeFunctionData } = await import("viem");

      const data = encodeFunctionData({
        abi: InteractionABI,
        functionName: "interact",
        args: [action, encodedMeta],
      });

      const hash = await provider.request!({
        method: "eth_sendTransaction",
        params: [
          {
            from: account,
            to: interactionAddress,
            data,
            value: `0x${valueBigInt.toString(16)}`,
          },
        ],
      });

      return hash as `0x${string}`;
    } else {
      // Ethers v6 path
      const { Contract } = await import("ethers");

      // Get signer from provider
      let signer = provider;
      if (typeof provider.getSigner === "function") {
        signer = await provider.getSigner(account);
      }

      const contract = new Contract(interactionAddress, InteractionABI, signer);
      const tx = await contract.interact(action, encodedMeta, {
        value: valueBigInt,
      });

      return tx.hash as `0x${string}`;
    }
  } catch (error: any) {
    // Provide helpful error messages
    if (error.message?.includes("insufficient fee")) {
      throw new Error(
        `费用不足：需要至少 ${feeWei.toString()} wei (约 ${(Number(feeWei) / 1e18).toFixed(6)} ETH)`
      );
    }
    if (error.message?.includes("action not allowed")) {
      throw new Error(`操作 "${action}" 不在允许列表中`);
    }
    throw new Error(`交互失败: ${error.message || error}`);
  }
}

/**
 * Records an interaction with ERC20 token fee payment (simplified signature)
 * @param provider Provider instance
 * @param token ERC20 token address
 * @param amount Amount of tokens to pay as fee
 * @param action Action string (e.g., "send_pixelmug", "aio_rpc_call")
 * @param meta Metadata as JSON bytes or object (will be encoded)
 * @param options Optional: interactionAddress, account (if not provided, will try to infer from provider)
 * @returns Transaction hashes [approvalTxHash, interactTxHash] (approval may be skipped if sufficient)
 */
export async function interact20(
  provider: ProviderLike,
  token: Address,
  amount: BigNumberish,
  action: string,
  meta: BytesLike,
  options?: { interactionAddress?: Address; account?: Address }
): Promise<[`0x${string}` | null, `0x${string}`]>;

/**
 * Records an interaction with ERC20 token fee payment (full options)
 * @param provider Provider instance
 * @param options Interaction20 options
 * @returns Transaction hashes [approvalTxHash, interactTxHash] (approval may be skipped if sufficient)
 */
export async function interact20(
  provider: ProviderLike,
  options: Interact20Options
): Promise<[`0x${string}` | null, `0x${string}`]>;

/**
 * Records an interaction with ERC20 token fee payment
 * @param provider Provider instance
 * @param tokenOrOptions Token address or full options object
 * @param amount Amount (if using simplified signature)
 * @param action Action string (if using simplified signature)
 * @param meta Metadata (if using simplified signature)
 * @param options Optional options (if using simplified signature)
 * @returns Transaction hashes [approvalTxHash, interactTxHash]
 */
export async function interact20(
  provider: ProviderLike,
  tokenOrOptions: Address | Interact20Options,
  amount?: BigNumberish,
  action?: string,
  meta?: BytesLike,
  options?: { interactionAddress?: Address; account?: Address }
): Promise<[`0x${string}` | null, `0x${string}`]> {
  // Handle function overload
  let interactionAddress: Address;
  let account: Address;
  let token: Address;
  let finalAmount: BigNumberish;
  let finalAction: string;
  let finalMeta: BytesLike;

  if (typeof tokenOrOptions === "object" && "token" in tokenOrOptions) {
    // Full options signature
    const opts = tokenOrOptions as Interact20Options;
    interactionAddress = opts.interactionAddress;
    account = opts.account;
    token = opts.token;
    finalAmount = opts.amount;
    finalAction = opts.action;
    finalMeta = opts.meta;
  } else {
    // Simplified signature
    token = tokenOrOptions as Address;
    finalAmount = amount!;
    finalAction = action!;
    finalMeta = meta!;
    interactionAddress = options?.interactionAddress || globalInteractionAddress || "";
    account = options?.account || "";

    if (!interactionAddress) {
      throw new Error("Interaction contract address is required. Either pass it in options or set it globally using setInteractionAddress()");
    }
    if (!account) {
      // Try to get account from provider
      if (typeof provider.getAddress === "function") {
        account = await provider.getAddress();
      } else {
        throw new Error("Account address is required. Please provide it in options or use a signer that has getAddress()");
      }
    }
  }

  // Encode meta if needed
  const encodedMeta = encodeMeta(finalMeta);
  const amountBigInt = typeof finalAmount === "bigint" ? finalAmount : BigInt(finalAmount.toString());

  try {
    let approvalTxHash: `0x${string}` | null = null;

    if (isViemProvider(provider)) {
      // Viem/wagmi path
      const { encodeFunctionData } = await import("viem");
      const { createPublicClient, http } = await import("viem");
      const publicClient = createPublicClient({
        transport: http(),
        // @ts-ignore
        chain: provider.chain || undefined,
      });

      // Check current allowance
      const allowance = await publicClient.readContract({
        address: token,
        abi: AIOERC20ABI,
        functionName: "allowance",
        args: [account, interactionAddress],
      });

      // Approve if needed
      if (allowance < amountBigInt) {
        const approveData = encodeFunctionData({
          abi: AIOERC20ABI,
          functionName: "approve",
          args: [interactionAddress, amountBigInt],
        });

        approvalTxHash = (await provider.request!({
          method: "eth_sendTransaction",
          params: [
            {
              from: account,
              to: token,
              data: approveData,
            },
          ],
        })) as `0x${string}`;

        // Wait for approval (optional - you might want to remove this for better UX)
        // await publicClient.waitForTransactionReceipt({ hash: approvalTxHash });
      }

      // Call interact20
      const interactData = encodeFunctionData({
        abi: InteractionABI,
        functionName: "interact20",
        args: [token, amountBigInt, finalAction, encodedMeta],
      });

      const interactTxHash = (await provider.request!({
        method: "eth_sendTransaction",
        params: [
          {
            from: account,
            to: interactionAddress,
            data: interactData,
          },
        ],
      })) as `0x${string}`;

      return [approvalTxHash, interactTxHash];
    } else {
      // Ethers v6 path
      const { Contract } = await import("ethers");

      // Get signer
      let signer = provider;
      if (typeof provider.getSigner === "function") {
        signer = await provider.getSigner(account);
      }

      const tokenContract = new Contract(token, AIOERC20ABI, signer);
      const interactionContract = new Contract(interactionAddress, InteractionABI, signer);

      // Check current allowance
      const allowance = await tokenContract.allowance(account, interactionAddress);

      // Approve if needed
      if (allowance < amountBigInt) {
        const approveTx = await tokenContract.approve(interactionAddress, amountBigInt);
        approvalTxHash = approveTx.hash as `0x${string}`;
        // Optionally wait for approval
        // await approveTx.wait();
      }

      // Call interact20
      const interactTx = await interactionContract.interact20(token, amountBigInt, finalAction, encodedMeta);
      const interactTxHash = interactTx.hash as `0x${string}`;

      return [approvalTxHash, interactTxHash];
    }
  } catch (error: any) {
    // Provide helpful error messages
    if (error.message?.includes("insufficient allowance") || error.message?.includes("ERC20: transfer amount exceeds allowance")) {
      throw new Error(
        `授权不足：请先授权 ${interactionAddress} 使用您的代币。请调用 approve 函数。`
      );
    }
    if (error.message?.includes("action not allowed")) {
      throw new Error(`操作 "${finalAction}" 不在允许列表中`);
    }
    throw new Error(`交互失败: ${error.message || error}`);
  }
}

// ============================================================================
// Utility: Check and Request Approval
// ============================================================================

/**
 * Checks if sufficient allowance exists and requests approval if needed
 * @param provider Provider instance
 * @param account User account
 * @param token Token address
 * @param spender Spender address (Interaction contract)
 * @param amount Required amount
 * @returns Approval transaction hash if approval was needed, null otherwise
 */
export async function ensureApproval(
  provider: ProviderLike,
  account: Address,
  token: Address,
  spender: Address,
  amount: BigNumberish
): Promise<`0x${string}` | null> {
  const amountBigInt = typeof amount === "bigint" ? amount : BigInt(amount.toString());

  try {
    if (isViemProvider(provider)) {
      const { createPublicClient, http, encodeFunctionData } = await import("viem");
      const publicClient = createPublicClient({
        transport: http(),
        // @ts-ignore
        chain: provider.chain || undefined,
      });

      const allowance = await publicClient.readContract({
        address: token,
        abi: AIOERC20ABI,
        functionName: "allowance",
        args: [account, spender],
      });

      if (allowance >= amountBigInt) {
        return null; // Already approved
      }

      const approveData = encodeFunctionData({
        abi: AIOERC20ABI,
        functionName: "approve",
        args: [spender, amountBigInt],
      });

      return (await provider.request!({
        method: "eth_sendTransaction",
        params: [
          {
            from: account,
            to: token,
            data: approveData,
          },
        ],
      })) as `0x${string}`;
    } else {
      const { Contract } = await import("ethers");
      let signer = provider;
      if (typeof provider.getSigner === "function") {
        signer = await provider.getSigner(account);
      }

      const tokenContract = new Contract(token, AIOERC20ABI, signer);
      const allowance = await tokenContract.allowance(account, spender);

      if (allowance >= amountBigInt) {
        return null;
      }

      const tx = await tokenContract.approve(spender, amountBigInt);
      return tx.hash as `0x${string}`;
    }
  } catch (error: any) {
    throw new Error(`授权失败: ${error.message || error}`);
  }
}

