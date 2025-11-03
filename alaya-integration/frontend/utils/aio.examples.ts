/**
 * @fileoverview Example usage of AIO Integration Helpers
 * @description Examples for both wagmi/viem and ethers v6
 */

import { getConfig, interact, interact20, ensureApproval, encodeMeta, setInteractionAddress } from "./aio";
import type { Address } from "viem";

// ============================================================================
// Example 1: Using with Wagmi/Viem
// ============================================================================

/**
 * Example: Interact with ETH payment using wagmi
 */
export async function exampleWagmiInteract() {
  // Assuming you're using wagmi hooks
  const { useWalletClient, usePublicClient } = await import("wagmi");
  
  // In a React component:
  /*
  import { useWalletClient, usePublicClient } from 'wagmi';
  import { getConfig, interact, setInteractionAddress } from '@/utils/aio';
  
  function MyComponent() {
    const { data: walletClient } = useWalletClient();
    const publicClient = usePublicClient();
    const { address } = useAccount();
    
    const interactionAddress = "0x..." as Address; // Your Interaction contract address
    
    const handleInteract = async () => {
      try {
        // Option 1: Set global interaction address once
        setInteractionAddress(interactionAddress);
        
        // 1. Get config (simplified - uses global address)
        const config = await getConfig(publicClient);
        console.log("Fee required:", config.feeWei.toString());
        console.log("Fee distributor:", config.feeDistributor);
        
        // 2. Prepare meta (JSON object)
        const metaObject = {
          userId: "user123",
          timestamp: Date.now(),
          actionData: { /* your data */ }
        };
        
        // 3. Interact with ETH (simplified signature)
        const txHash = await interact(
          walletClient,
          "send_pixelmug", // Short action string
          metaObject, // JSON object - will be encoded automatically
          config.feeWei, // Pay the required fee
          { account: address! } // Optional: account (if walletClient doesn't have getAddress)
        );
        
        console.log("Transaction hash:", txHash);
      } catch (error) {
        console.error("Error:", error);
        // Error messages are in Chinese with helpful hints
      }
    };
    
    return <button onClick={handleInteract}>Interact</button>;
  }
  */
}

/**
 * Example: Interact with ERC20 token payment using wagmi
 */
export async function exampleWagmiInteract20() {
  /*
  import { useWalletClient, usePublicClient } from 'wagmi';
  import { interact20, ensureApproval, setInteractionAddress } from '@/utils/aio';
  
  function MyComponent() {
    const { data: walletClient } = useWalletClient();
    const { address } = useAccount();
    
    const interactionAddress = "0x..." as Address;
    const tokenAddress = "0x..." as Address; // AIO or other ERC20
    const amount = BigInt("1000000000000000000"); // 1 token (18 decimals)
    
    const handleInteract20 = async () => {
      try {
        // Option 1: Let interact20 handle approval automatically (simplified signature)
        const [approvalTx, interactTx] = await interact20(
          walletClient,
          tokenAddress, // Token address
          amount, // Amount to pay
          "aio_rpc_call", // Action string
          { rpcMethod: "generate", params: {} }, // Meta as JSON object
          { account: address! } // Optional: account and interactionAddress
        );
        
        if (approvalTx) {
          console.log("Approval transaction:", approvalTx);
        }
        console.log("Interact transaction:", interactTx);
        
        // Option 2: Manually ensure approval first
        // const approvalTx = await ensureApproval(
        //   walletClient,
        //   address!,
        //   tokenAddress,
        //   interactionAddress,
        //   amount
        // );
        // if (approvalTx) {
        //   await waitForTransaction({ hash: approvalTx });
        // }
        // Then call interact20 (approval will be skipped)
      } catch (error) {
        console.error("Error:", error);
      }
    };
    
    return <button onClick={handleInteract20}>Interact with Token</button>;
  }
  */
}

// ============================================================================
// Example 2: Using with Ethers v6
// ============================================================================

/**
 * Example: Interact with ETH payment using ethers v6
 */
export async function exampleEthersInteract() {
  /*
  import { ethers } from 'ethers';
  import { getConfig, interact, setInteractionAddress } from '@/utils/aio';
  
  async function main() {
    // Setup provider and signer
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const address = await signer.getAddress();
    
    const interactionAddress = "0x..." as Address;
    
    try {
      // Option 1: Set global interaction address
      setInteractionAddress(interactionAddress);
      
      // 1. Get config (simplified)
      const config = await getConfig(signer);
      console.log("Fee required:", config.feeWei.toString());
      console.log("Fee distributor:", config.feeDistributor);
      
      // 2. Prepare meta as JSON object (will be encoded automatically)
      const meta = {
        action: "send_pixelmug",
        data: { /* your data */ }
      };
      
      // 3. Interact (simplified signature)
      // signer.getAddress() will be called automatically if account not provided
      const txHash = await interact(
        signer,
        "send_pixelmug",
        meta,
        config.feeWei
      );
      
      console.log("Transaction hash:", txHash);
      
      // Wait for transaction
      const receipt = await provider.waitForTransaction(txHash);
      console.log("Transaction confirmed:", receipt);
    } catch (error) {
      console.error("Error:", error);
    }
  }
  */
}

/**
 * Example: Interact with ERC20 token payment using ethers v6
 */
export async function exampleEthersInteract20() {
  /*
  import { ethers } from 'ethers';
  import { interact20, setInteractionAddress } from '@/utils/aio';
  
  async function main() {
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const address = await signer.getAddress();
    
    const interactionAddress = "0x..." as Address;
    const tokenAddress = "0x..." as Address;
    const amount = ethers.parseEther("1"); // 1 token
    
    try {
      // Set global interaction address (optional)
      setInteractionAddress(interactionAddress);
      
      const [approvalTx, interactTx] = await interact20(
        signer,
        tokenAddress,
        amount,
        "aio_rpc_call",
        { rpcMethod: "generate" }, // Meta as JSON object
        { account: address as Address } // Optional
      );
      
      if (approvalTx) {
        console.log("Approval:", approvalTx);
        await provider.waitForTransaction(approvalTx);
      }
      
      console.log("Interact:", interactTx);
      const receipt = await provider.waitForTransaction(interactTx);
      console.log("Confirmed:", receipt);
    } catch (error) {
      console.error("Error:", error);
    }
  }
  */
}

// ============================================================================
// Example 3: Common Patterns
// ============================================================================

/**
 * Pattern: Check fee before interacting
 */
export async function exampleCheckFeeFirst() {
  /*
  // Set global interaction address
  setInteractionAddress(interactionAddress);
  
  // Get config (simplified)
  const config = await getConfig(provider);
  
  // Check if user has enough balance
  if (userBalance < config.feeWei) {
    alert(`余额不足！需要 ${ethers.formatEther(config.feeWei)} ETH`);
    return;
  }
  
  // Proceed with interaction (simplified signature)
  await interact(
    provider,
    "send_pixelmug",
    {}, // Meta as JSON object
    config.feeWei,
    { account: userAddress } // Optional
  );
  */
}

/**
 * Pattern: Handle errors gracefully
 */
export async function exampleErrorHandling() {
  /*
  try {
    await interact(provider, options);
  } catch (error: any) {
    if (error.message.includes("费用不足")) {
      // Show fee amount modal
      showFeeModal(config.feeWei);
    } else if (error.message.includes("授权不足")) {
      // Show approval button
      showApprovalButton();
    } else if (error.message.includes("不在允许列表中")) {
      // Show action not allowed message
      showError("该操作当前不可用");
    } else {
      // Generic error
      showError(error.message);
    }
  }
  */
}

/**
 * Pattern: Pre-approve tokens for better UX
 */
export async function examplePreApprove() {
  /*
  // Set global interaction address
  setInteractionAddress(interactionAddress);
  
  // On page load or user action
  const config = await getConfig(provider);
  const tokenAmount = config.feeWei; // or custom amount
  
  // Check if approval needed
  const approvalTx = await ensureApproval(
    provider,
    userAddress,
    tokenAddress,
    interactionAddress,
    tokenAmount
  );
  
  if (approvalTx) {
    // Show "Approving..." state
    await waitForTransaction(approvalTx);
    // Show "Approved!" success message
  }
  
  // Later, when user clicks interact:
  // Approval will be skipped, transaction goes through immediately (simplified signature)
  const [, interactTx] = await interact20(
    provider,
    tokenAddress,
    tokenAmount,
    "send_pixelmug",
    {}, // Meta as JSON object
    { account: userAddress } // Optional
  );
  */
}

// ============================================================================
// Action String Recommendations
// ============================================================================

/**
 * Recommended action strings (short, descriptive):
 * 
 * - "send_pixelmug" - Send a pixel mug
 * - "aio_rpc_call" - AIO RPC call
 * - "verify_proof" - Verify a proof
 * - "submit_data" - Submit data
 * - "mint_nft" - Mint NFT
 * - "claim_reward" - Claim reward
 * 
 * Keep action strings short (under 20 chars) to save gas.
 * Store detailed data in meta JSON.
 */

