/**
 * @fileoverview React 组件 - 领取 AIO 奖励
 * @description 用于领取已完成交互的 AIO token 奖励
 */

'use client';

import { useState, useEffect } from 'react';
import { useAccount, useWalletClient, usePublicClient, useWaitForTransactionReceipt } from 'wagmi';
import { claimAIO, setInteractionAddress } from '../utils/aio';
import { diagnoseClaimAIO } from '../utils/diagnoseClaim';
import type { Address } from '../utils/aio';

// 配置：Interaction 合约地址（应该从环境变量或配置文件中读取）
const INTERACTION_ADDRESS = process.env.NEXT_PUBLIC_INTERACTION_ADDRESS as Address;

interface ClaimButtonProps {
  /** 要领取的 AIO token 数量（以 wei 为单位） */
  amount: bigint | number | string;
  /** 自定义按钮文本 */
  buttonText?: string;
  /** 是否禁用按钮 */
  disabled?: boolean;
  /** 领取成功回调 */
  onSuccess?: (txHash: `0x${string}`) => void;
  /** 领取失败回调 */
  onError?: (error: Error) => void;
}

/**
 * ClaimButton 组件 - 领取 AIO 奖励
 * 
 * 使用示例：
 * ```tsx
 * <ClaimButton
 *   amount="150000000000000000000" // 150 AIO tokens (in wei)
 *   onSuccess={(hash) => console.log("领取成功:", hash)}
 *   onError={(err) => console.error("领取失败:", err)}
 * />
 * ```
 */
export function ClaimButton({
  amount,
  buttonText = '领取 AIO 奖励',
  disabled = false,
  onSuccess,
  onError,
}: ClaimButtonProps) {
  const { address, isConnected } = useAccount();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();

  const [isLoading, setIsLoading] = useState(false);
  const [txHash, setTxHash] = useState<`0x${string}` | null>(null);
  const [error, setError] = useState<string | null>(null);

  // 设置全局 Interaction 地址
  useEffect(() => {
    if (INTERACTION_ADDRESS) {
      setInteractionAddress(INTERACTION_ADDRESS);
    }
  }, []);

  // 等待交易确认
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash: txHash || undefined,
  });

  // 处理领取
  const handleClaim = async () => {
    if (!walletClient || !address) {
      setError('请先连接钱包');
      return;
    }

    if (!INTERACTION_ADDRESS) {
      setError('Interaction 合约地址未配置');
      return;
    }

    const amountBigInt = typeof amount === "bigint" ? amount : BigInt(amount.toString());
    if (amountBigInt === 0n) {
      setError('领取数量不能为零');
      return;
    }

    setIsLoading(true);
    setError(null);
    setTxHash(null);

    try {
      const hash = await claimAIO(
        walletClient,
        amountBigInt,
        {
          interactionAddress: INTERACTION_ADDRESS,
          account: address,
        }
      );

      setTxHash(hash);
      onSuccess?.(hash);
    } catch (err: any) {
      const errorMessage = err.message || '领取失败';
      setError(errorMessage);
      onError?.(err);
      console.error('领取失败:', err);
      
      // 如果错误是 "missing revert data"，尝试诊断问题
      if (err.error?.code === 'CALL_EXCEPTION' || err.message?.includes('missing revert data')) {
        console.log('检测到 CALL_EXCEPTION，开始诊断...');
        try {
          const diagnosis = await diagnoseClaimAIO(
            publicClient as any,
            INTERACTION_ADDRESS,
            amountBigInt,
            address
          );
          console.log('诊断结果:', diagnosis);
          
          // 如果有明确的错误信息，更新错误提示
          const failedChecks = diagnosis.checks.filter(c => !c.passed);
          if (failedChecks.length > 0) {
            const detailedError = failedChecks.map(c => c.message).join('; ');
            setError(`${errorMessage}\n\n诊断信息: ${detailedError}`);
          }
          
          // 输出建议到控制台
          if (diagnosis.suggestions.length > 0) {
            console.log('修复建议:', diagnosis.suggestions);
          }
        } catch (diagnosisError) {
          console.error('诊断过程失败:', diagnosisError);
        }
      }
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
    !isConnected;

  const amountBigInt = typeof amount === "bigint" ? amount : BigInt(amount.toString());

  return (
    <div className="claim-button-container">
      {/* 奖励信息 */}
      {amountBigInt > 0n && (
        <div className="reward-info" style={{ marginBottom: '8px', fontSize: '14px', color: '#666' }}>
          可领取奖励: {formatReward(amountBigInt)}
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
  // 示例：150 AIO tokens (150 * 10^18 wei)
  const exampleAmount = BigInt("150000000000000000000");

  return (
    <div style={{ padding: '20px' }}>
      <h2>领取 AIO 奖励示例</h2>

      {/* 示例：领取 150 AIO tokens */}
      <div style={{ marginBottom: '20px' }}>
        <h3>示例：领取 150 AIO tokens</h3>
        <p style={{ fontSize: '12px', color: '#666', marginBottom: '8px' }}>
          数量: 150 AIO (150000000000000000000 wei)
        </p>
        <ClaimButton
          amount={exampleAmount}
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

