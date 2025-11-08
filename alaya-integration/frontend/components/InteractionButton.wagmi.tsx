/**
 * @fileoverview React 组件示例 - 使用 Wagmi 与 Interaction 合约交互
 * @description 完整的 React 组件示例，展示如何使用 wagmi hooks 调用 Interaction 合约
 */

'use client';

import { useState, useEffect } from 'react';
import { useAccount, useWalletClient, usePublicClient, useWaitForTransactionReceipt } from 'wagmi';
import { getConfig, interact, setInteractionAddress } from '../utils/aio';
import type { Address } from '../utils/aio';

// 配置：Interaction 合约地址（应该从环境变量或配置文件中读取）
const INTERACTION_ADDRESS = process.env.NEXT_PUBLIC_INTERACTION_ADDRESS as Address;

interface InteractionButtonProps {
  /** Action 字符串（如 "send_pixelmug"） */
  action: string;
  /** Meta 数据对象（会被自动编码为 JSON bytes） */
  meta?: Record<string, any>;
  /** 自定义按钮文本 */
  buttonText?: string;
  /** 是否禁用按钮 */
  disabled?: boolean;
  /** 交互成功回调 */
  onSuccess?: (txHash: `0x${string}`) => void;
  /** 交互失败回调 */
  onError?: (error: Error) => void;
}

/**
 * InteractionButton 组件
 * 
 * 使用示例：
 * ```tsx
 * <InteractionButton
 *   action="send_pixelmug"
 *   meta={{ userId: "123", pixelData: "..." }}
 *   onSuccess={(hash) => console.log("成功:", hash)}
 *   onError={(err) => console.error("失败:", err)}
 * />
 * ```
 */
export function InteractionButton({
  action,
  meta = {},
  buttonText = '执行交互',
  disabled = false,
  onSuccess,
  onError,
}: InteractionButtonProps) {
  const { address, isConnected } = useAccount();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();

  const [isLoading, setIsLoading] = useState(false);
  const [txHash, setTxHash] = useState<`0x${string}` | null>(null);
  const [feeWei, setFeeWei] = useState<bigint | null>(null);
  const [error, setError] = useState<string | null>(null);

  // 设置全局 Interaction 地址
  useEffect(() => {
    if (INTERACTION_ADDRESS) {
      setInteractionAddress(INTERACTION_ADDRESS);
    }
  }, []);

  // 加载配置（费用信息）
  useEffect(() => {
    if (!publicClient || !INTERACTION_ADDRESS) return;

    const loadConfig = async () => {
      try {
        const config = await getConfig(publicClient, INTERACTION_ADDRESS);
        setFeeWei(config.feeWei);
      } catch (err: any) {
        console.error('加载配置失败:', err);
        setError(err.message || '加载配置失败');
      }
    };

    loadConfig();
  }, [publicClient]);

  // 等待交易确认
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash: txHash || undefined,
  });

  // 处理交互
  const handleInteract = async () => {
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
      // 获取最新配置（确保费用是最新的）
      const config = await getConfig(publicClient, INTERACTION_ADDRESS);

      // 执行交互
      const hash = await interact(
        walletClient,
        action,
        meta,
        config.feeWei,
        {
          interactionAddress: INTERACTION_ADDRESS,
          account: address,
        }
      );

      setTxHash(hash);
      onSuccess?.(hash);
    } catch (err: any) {
      const errorMessage = err.message || '交互失败';
      setError(errorMessage);
      onError?.(err);
      console.error('交互失败:', err);
    } finally {
      setIsLoading(false);
    }
  };

  // 格式化费用显示
  const formatFee = (wei: bigint | null): string => {
    if (!wei) return '加载中...';
    const eth = Number(wei) / 1e18;
    if (eth < 0.001) {
      return `${Number(wei)} wei`;
    }
    return `${eth.toFixed(6)} ETH`;
  };

  // 检查是否应该禁用按钮
  const isButtonDisabled = disabled || isLoading || isConfirming || !isConnected || !feeWei;

  return (
    <div className="interaction-button-container">
      {/* 费用显示 */}
      {feeWei && (
        <div className="fee-info" style={{ marginBottom: '8px', fontSize: '14px', color: '#666' }}>
          费用: {formatFee(feeWei)}
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
          {isConfirmed && <span style={{ color: '#4caf50' }}>✓ 交易已确认</span>}
          <div style={{ fontSize: '12px', color: '#666', wordBreak: 'break-all' }}>
            交易哈希: {txHash}
          </div>
        </div>
      )}

      {/* 交互按钮 */}
      <button
        onClick={handleInteract}
        disabled={isButtonDisabled}
        style={{
          padding: '10px 20px',
          fontSize: '16px',
          backgroundColor: isButtonDisabled ? '#ccc' : '#007bff',
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
export function InteractionButtonExample() {
  return (
    <div style={{ padding: '20px' }}>
      <h2>Interaction 交互示例</h2>

      {/* 示例 1: 发送像素杯 */}
      <div style={{ marginBottom: '20px' }}>
        <h3>示例 1: 发送像素杯</h3>
        <InteractionButton
          action="send_pixelmug"
          meta={{
            userId: 'user123',
            pixelData: '0x1234...',
            timestamp: Date.now(),
          }}
          buttonText="发送像素杯"
          onSuccess={(hash) => {
            console.log('发送成功:', hash);
            alert(`交易已提交: ${hash}`);
          }}
          onError={(err) => {
            console.error('发送失败:', err);
            alert(`发送失败: ${err.message}`);
          }}
        />
      </div>

      {/* 示例 2: AIO RPC 调用 */}
      <div style={{ marginBottom: '20px' }}>
        <h3>示例 2: AIO RPC 调用</h3>
        <InteractionButton
          action="aio_rpc_call"
          meta={{
            rpcMethod: 'generate',
            params: { prompt: 'A beautiful landscape' },
          }}
          buttonText="调用 AIO RPC"
          onSuccess={(hash) => console.log('RPC 调用成功:', hash)}
        />
      </div>

      {/* 示例 3: 提交数据 */}
      <div style={{ marginBottom: '20px' }}>
        <h3>示例 3: 提交数据</h3>
        <InteractionButton
          action="submit_data"
          meta={{
            dataType: 'user_profile',
            data: { name: 'Alice', age: 30 },
          }}
          buttonText="提交数据"
        />
      </div>
    </div>
  );
}

