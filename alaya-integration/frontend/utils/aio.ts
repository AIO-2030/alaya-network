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
  aioToken: Address;
  aioRewardPool: Address;
}

export interface ClaimStatus {
  claimed: boolean;
  rewardAmount: bigint;
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

// ============================================================================
// ABI Imports (minimal ABIs)
// ============================================================================

import InteractionABI from "../../abi/Interaction.json";
import FeeDistributorABI from "../../abi/FeeDistributor.json";

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
 * @returns Configuration object with feeWei, feeDistributor, aioToken, and aioRewardPool
 */
export async function getConfig(
  provider: ProviderLike,
  interactionAddress?: Address
): Promise<Config> {
  const address = interactionAddress || globalInteractionAddress;
  if (!address) {
    throw new Error("Interaction contract address is required. Either pass it as parameter or set it globally using setInteractionAddress()");
  }
  try {
    if (isViemProvider(provider)) {
      // Viem/wagmi path
      // @ts-ignore - viem is an optional dependency
      const { createPublicClient, http } = await import("viem");
      const publicClient = createPublicClient({
        transport: http(),
        // @ts-ignore - provider might have chain info
        chain: provider.chain || undefined,
      });

      const result = await publicClient.readContract({
        address: address as `0x${string}`,
        abi: InteractionABI as any,
        functionName: "getConfig",
        args: [],
      }) as [bigint, `0x${string}`, `0x${string}`, `0x${string}`];

      return {
        feeWei: result[0],
        feeDistributor: result[1] as Address,
        aioToken: result[2] as Address,
        aioRewardPool: result[3] as Address,
      };
    } else {
      // Ethers v6 path
      // @ts-ignore - ethers is an optional dependency
      const { Contract } = await import("ethers");
      const contract = new Contract(address, InteractionABI as any, provider as any);
      const [feeWei, feeDistributor, aioToken, aioRewardPool] = await contract.getConfig();

      return {
        feeWei: BigInt(feeWei.toString()),
        feeDistributor: feeDistributor as Address,
        aioToken: aioToken as Address,
        aioRewardPool: aioRewardPool as Address,
      };
    }
  } catch (error: any) {
    throw new Error(`Failed to get config: ${error.message || error}`);
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
      // @ts-ignore - viem is an optional dependency
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
      // @ts-ignore - ethers is an optional dependency
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
 * Claims AIO tokens
 * @param provider Provider instance (viem or ethers)
 * @param amount Amount of AIO tokens to claim (in wei)
 * @param options Optional: interactionAddress, account
 * @returns Transaction hash
 */
export async function claimAIO(
  provider: ProviderLike,
  amount: BigNumberish,
  options?: { interactionAddress?: Address; account?: Address }
): Promise<`0x${string}`> {
  const interactionAddress = options?.interactionAddress || globalInteractionAddress;
  if (!interactionAddress) {
    throw new Error("Interaction contract address is required. Either pass it in options or set it globally using setInteractionAddress()");
  }

  let account: Address = options?.account || "";
  if (!account) {
    if (typeof provider.getAddress === "function") {
      account = await provider.getAddress();
    } else {
      throw new Error("Account address is required. Please provide it in options or use a signer that has getAddress()");
    }
  }

  const amountBigInt = typeof amount === "bigint" ? amount : BigInt(amount.toString());

  if (amountBigInt === 0n) {
    throw new Error("领取数量不能为零");
  }

  try {
    if (isViemProvider(provider)) {
      // Viem/wagmi path
      // @ts-ignore - viem is an optional dependency
      const { encodeFunctionData } = await import("viem");

      const data = encodeFunctionData({
        abi: InteractionABI,
        functionName: "claimAIO",
        args: [amountBigInt],
      });

      const hash = await provider.request!({
        method: "eth_sendTransaction",
        params: [
          {
            from: account,
            to: interactionAddress,
            data,
          },
        ],
      });

      return hash as `0x${string}`;
    } else {
      // Ethers v6 path
      // @ts-ignore - ethers is an optional dependency
      const { Contract } = await import("ethers");

      let signer = provider;
      if (typeof provider.getSigner === "function") {
        signer = await provider.getSigner(account);
      }

      const contract = new Contract(interactionAddress, InteractionABI, signer);
      const tx = await contract.claimAIO(amountBigInt);

      return tx.hash as `0x${string}`;
    }
  } catch (error: any) {
    // Provide helpful error messages
    if (error.message?.includes("AIO token not set")) {
      throw new Error("AIO token 地址未设置");
    }
    if (error.message?.includes("AIO reward pool not set")) {
      throw new Error("AIO 奖励池地址未设置");
    }
    if (error.message?.includes("amount cannot be zero")) {
      throw new Error("领取数量不能为零");
    }
    if (error.message?.includes("AIO transfer failed")) {
      throw new Error("AIO 转账失败，可能是奖励池余额不足或未授权");
    }
    throw new Error(`领取奖励失败: ${error.message || error}`);
  }
}

/**
 * Gets claim status for a specific interaction
 * @deprecated 此函数当前不可用，因为 Interaction 合约中没有 getClaimStatus 函数
 * @param provider Provider instance (viem or ethers)
 * @param user User address
 * @param action Action string identifier
 * @param timestamp Block timestamp of the original interaction
 * @param interactionAddress Optional interaction contract address (uses global if not provided)
 * @returns Claim status with claimed flag and reward amount
 * @throws Error 因为合约中没有此函数，调用会失败
 */
export async function getClaimStatus(
  provider: ProviderLike,
  user: Address,
  action: string,
  timestamp: BigNumberish,
  interactionAddress?: Address
): Promise<ClaimStatus> {
  const address = interactionAddress || globalInteractionAddress;
  if (!address) {
    throw new Error("Interaction contract address is required. Either pass it as parameter or set it globally using setInteractionAddress()");
  }

  const timestampBigInt = typeof timestamp === "bigint" ? timestamp : BigInt(timestamp.toString());

  try {
    if (isViemProvider(provider)) {
      // Viem/wagmi path
      // @ts-ignore - viem is an optional dependency
      const { createPublicClient, http } = await import("viem");
      const publicClient = createPublicClient({
        transport: http(),
        // @ts-ignore - provider might have chain info
        chain: provider.chain || undefined,
      });

      const result = await publicClient.readContract({
        address: address,
        abi: InteractionABI,
        functionName: "getClaimStatus",
        args: [user, action, timestampBigInt],
      });

      return {
        claimed: result[0] as boolean,
        rewardAmount: result[1] as bigint,
      };
    } else {
      // Ethers v6 path
      // @ts-ignore - ethers is an optional dependency
      const { Contract } = await import("ethers");
      const contract = new Contract(address, InteractionABI, provider);
      const [claimed, rewardAmount] = await contract.getClaimStatus(user, action, timestampBigInt);

      return {
        claimed: claimed as boolean,
        rewardAmount: BigInt(rewardAmount.toString()),
      };
    }
  } catch (error: any) {
    throw new Error(`获取领取状态失败: ${error.message || error}`);
  }
}


