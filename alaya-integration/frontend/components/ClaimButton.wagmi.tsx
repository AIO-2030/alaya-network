/**
 * @fileoverview React 组件 - 领取 AIO 奖励
 * @description 用于领取已完成交互的 AIO token 奖励
 */

'use client';

import { useState, useEffect } from 'react';
import { useAccount, useWalletClient, usePublicClient, useWaitForTransactionReceipt } from 'wagmi';
import { claimAIO, getClaimStatus, setInteractionAddress } from '../utils/aio';
import type { Address } from '../utils/aio';

// 配置：Interaction 合约地址（应该从环境变量或配置文件中读取）
const INTERACTION_ADDRESS = process.env.NEXT_PUBLIC_INTERACTION_ADDRESS as Address;

interface ClaimButtonProps {
  /** Action 字符串（必须与原始交互匹配） */
  action: string;
  /** 原始交互的区块时间戳（从 InteractionRecorded 事件中获取） */
  timestamp: bigint | number | string;
  /** 自定义按钮文本 */
  buttonText?: string;
  /** 是否禁用按钮 */
  disabled?: boolean;
  /** 领取成功回调 */
  onSuccess?: (txHash: `0x${string}`) => void;
  /** 领取失败回调 */
  onError?: (error: Error) => void;
  /** 是否自动检查领取状态 */
  autoCheckStatus?: boolean;
}

/**
 * ClaimButton 组件 - 领取 AIO 奖励
 * 
 * 使用示例：
 * ```tsx
 * <ClaimButton
 *   action="send_pixelmug"
 *   timestamp={1699123456}
 *   onSuccess={(hash) => console.log("领取成功:", hash)}
 *   onError={(err) => console.error("领取失败:", err)}
 * />
 * ```
 */
export function ClaimButton({
  action,
  timestamp,
  buttonText = '领取 AIO 奖励',
  disabled = false,
  onSuccess,
  onError,
  autoCheckStatus = true,
}: ClaimButtonProps) {
  const { address, isConnected } = useAccount();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();

  const [isLoading, setIsLoading] = useState(false);
  const [txHash, setTxHash] = useState<`0x${string}` | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [claimStatus, setClaimStatus] = useState<{ claimed: boolean; rewardAmount: bigint } | null>(null);

  // 设置全局 Interaction 地址
  useEffect(() => {
    if (INTERACTION_ADDRESS) {
      setInteractionAddress(INTERACTION_ADDRESS);
    }
  }, []);

  // 自动检查领取状态
  useEffect(() => {
    if (!autoCheckStatus || !publicClient || !address || !INTERACTION_ADDRESS) return;

    const checkStatus = async () => {
      try {
        const status = await getClaimStatus(
          publicClient,
          address,
          action,
          timestamp,
          INTERACTION_ADDRESS
        );
        setClaimStatus(status);
      } catch (err: any) {
        console.error('检查领取状态失败:', err);
        // 不设置错误，因为这只是状态检查
      }
    };

    checkStatus();
  }, [publicClient, address, action, timestamp, autoCheckStatus]);

  // 等待交易确认
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash: txHash || undefined,
  });

  // 处理领取
  const handleClaim = async () => {
    if (!walletClient || !address || !publicClient) {
      setError('请先连接钱包');
      return;
    }

    if (!INTERACTION_ADDRESS) {
      setError('Interaction 合约地址未配置');
      return;
    }

    setIsLoading(true);
    setError(null);
    setTxHash(null);

    try {
      const hash = await claimAIO(
        walletClient,
        action,
        timestamp,
        {
          interactionAddress: INTERACTION_ADDRESS,
          account: address,
        }
      );

      setTxHash(hash);
      onSuccess?.(hash);
      
      // 更新状态为已领取
      if (claimStatus) {
        setClaimStatus({ ...claimStatus, claimed: true });
      }
    } catch (err: any) {
      const errorMessage = err.message || '领取失败';
      setError(errorMessage);
      onError?.(err);
      console.error('领取失败:', err);
    } finally {
      setIsLoading(false);
    }
  };

  // 格式化奖励数量
  const formatReward = (amount: bigint | null): string => {
    if (!amount) return '加载中...';
    const tokens = Number(amount) / 1e18;
    if (tokens < 0.001) {
      return `${Number(amount)} wei`;
    }
    return `${tokens.toFixed(6)} AIO`;
  };

  // 检查是否应该禁用按钮
  const isButtonDisabled = 
    disabled || 
    isLoading || 
    isConfirming || 
    !isConnected || 
    (claimStatus?.claimed === true);

  // 如果已领取，显示已领取状态
  if (claimStatus?.claimed === true) {
    return (
      <div className="claim-button-container">
        <div style={{ padding: '10px', backgroundColor: '#e8f5e9', borderRadius: '4px', color: '#2e7d32' }}>
          ✓ 奖励已领取 ({formatReward(claimStatus.rewardAmount)})
        </div>
      </div>
    );
  }

  return (
    <div className="claim-button-container">
      {/* 奖励信息 */}
      {claimStatus && claimStatus.rewardAmount > 0n && (
        <div className="reward-info" style={{ marginBottom: '8px', fontSize: '14px', color: '#666' }}>
          可领取奖励: {formatReward(claimStatus.rewardAmount)}
        </div>
      )}

      {/* 错误提示 */}
      {error && (
        <div className="error-message" style={{ marginBottom: '8px', color: 'red', fontSize: '14px' }}>
          {error}
        </div>
      )}

      {/* 交易状态 */}
      {txHash && (
        <div className="tx-status" style={{ marginBottom: '8px', fontSize: '14px' }}>
          {isConfirming && <span style={{ color: '#ffa500' }}>确认中...</span>}
          {isConfirmed && <span style={{ color: '#4caf50' }}>✓ 领取成功</span>}
          <div style={{ fontSize: '12px', color: '#666', wordBreak: 'break-all' }}>
            交易哈希: {txHash}
          </div>
        </div>
      )}

      {/* 领取按钮 */}
      <button
        onClick={handleClaim}
        disabled={isButtonDisabled}
        style={{
          padding: '10px 20px',
          fontSize: '16px',
          backgroundColor: isButtonDisabled ? '#ccc' : '#4caf50',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: isButtonDisabled ? 'not-allowed' : 'pointer',
        }}
      >
        {isLoading
          ? '处理中...'
          : isConfirming
          ? '确认中...'
          : !isConnected
          ? '请连接钱包'
          : buttonText}
      </button>
    </div>
  );
}

/**
 * 使用示例组件
 */
export function ClaimButtonExample() {
  // 示例：从交互事件中获取的 timestamp
  const exampleTimestamp = Math.floor(Date.now() / 1000); // 当前时间戳（示例）

  return (
    <div style={{ padding: '20px' }}>
      <h2>领取 AIO 奖励示例</h2>

      {/* 示例：领取 send_pixelmug 的奖励 */}
      <div style={{ marginBottom: '20px' }}>
        <h3>示例：领取 send_pixelmug 奖励</h3>
        <p style={{ fontSize: '12px', color: '#666', marginBottom: '8px' }}>
          时间戳: {exampleTimestamp} (从 InteractionRecorded 事件中获取)
        </p>
        <ClaimButton
          action="send_pixelmug"
          timestamp={exampleTimestamp}
          buttonText="领取奖励"
          onSuccess={(hash) => {
            console.log('领取成功:', hash);
            alert(`奖励领取成功: ${hash}`);
          }}
          onError={(err) => {
            console.error('领取失败:', err);
            alert(`领取失败: ${err.message}`);
          }}
        />
      </div>
    </div>
  );
}

