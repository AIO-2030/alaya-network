/**
 * @fileoverview 诊断 claimAIO 失败原因的工具函数
 * @description 检查合约状态、余额、授权等，帮助定位问题
 */

import { getConfig, type ProviderLike, type Address } from './aio';
import InteractionABI from '../../abi/Interaction.json';
import AIOERC20ABI from '../../abi/AIOERC20.json';

export interface ClaimDiagnosis {
  /** 是否所有检查都通过 */
  allChecksPassed: boolean;
  /** 检查结果列表 */
  checks: Array<{
    name: string;
    passed: boolean;
    message: string;
    details?: any;
  }>;
  /** 建议的修复步骤 */
  suggestions: string[];
}

/**
 * 诊断 claimAIO 失败的原因
 * @param provider Provider 实例
 * @param interactionAddress Interaction 合约地址
 * @param amount 要领取的数量（wei）
 * @param userAddress 用户地址（可选，用于检查授权）
 * @returns 诊断结果
 */
export async function diagnoseClaimAIO(
  provider: ProviderLike,
  interactionAddress: Address,
  amount: bigint,
  userAddress?: Address
): Promise<ClaimDiagnosis> {
  const checks: ClaimDiagnosis['checks'] = [];
  const suggestions: string[] = [];

  try {
    // 检查 1: 获取合约配置
    let config;
    try {
      config = await getConfig(provider, interactionAddress);
      checks.push({
        name: '合约配置读取',
        passed: true,
        message: '成功读取合约配置',
        details: config,
      });
    } catch (error: any) {
      checks.push({
        name: '合约配置读取',
        passed: false,
        message: `无法读取合约配置: ${error.message}`,
      });
      suggestions.push('检查 Interaction 合约地址是否正确');
      suggestions.push('检查网络连接是否正常');
      return { allChecksPassed: false, checks, suggestions };
    }

    // 检查 2: AIO Token 是否已设置
    if (!config.aioToken || config.aioToken === '0x0000000000000000000000000000000000000000') {
      checks.push({
        name: 'AIO Token 配置',
        passed: false,
        message: 'AIO Token 地址未设置（为零地址）',
      });
      suggestions.push('需要调用 setAIOToken() 设置 AIO Token 地址');
    } else {
      checks.push({
        name: 'AIO Token 配置',
        passed: true,
        message: `AIO Token 已设置: ${config.aioToken}`,
      });
    }

    // 检查 3: Reward Pool 是否已设置
    if (!config.aioRewardPool || config.aioRewardPool === '0x0000000000000000000000000000000000000000') {
      checks.push({
        name: '奖励池配置',
        passed: false,
        message: '奖励池地址未设置（为零地址）',
      });
      suggestions.push('需要调用 setAIORewardPool() 设置奖励池地址');
    } else {
      checks.push({
        name: '奖励池配置',
        passed: true,
        message: `奖励池已设置: ${config.aioRewardPool}`,
      });
    }

    // 如果 Token 或 Reward Pool 未设置，提前返回
    if (!config.aioToken || config.aioToken === '0x0000000000000000000000000000000000000000' ||
        !config.aioRewardPool || config.aioRewardPool === '0x0000000000000000000000000000000000000000') {
      return { allChecksPassed: false, checks, suggestions };
    }

    // 检查 4: 奖励池余额
    try {
      if (isViemProvider(provider)) {
        const { createPublicClient, http } = await import('viem');
        const publicClient = createPublicClient({
          transport: http(),
          chain: (provider as any).chain || undefined,
        });

        const balance = await publicClient.readContract({
          address: config.aioToken as `0x${string}`,
          abi: AIOERC20ABI as any,
          functionName: 'balanceOf',
          args: [config.aioRewardPool as `0x${string}`],
        }) as bigint;

        if (balance < amount) {
          checks.push({
            name: '奖励池余额',
            passed: false,
            message: `奖励池余额不足: ${balance.toString()} < ${amount.toString()}`,
            details: {
              balance: balance.toString(),
              required: amount.toString(),
              shortfall: (amount - balance).toString(),
            },
          });
          suggestions.push(`需要向奖励池充值至少 ${amount.toString()} wei 的 AIO Token`);
        } else {
          checks.push({
            name: '奖励池余额',
            passed: true,
            message: `奖励池余额充足: ${balance.toString()} >= ${amount.toString()}`,
            details: {
              balance: balance.toString(),
              required: amount.toString(),
            },
          });
        }
      } else {
        // Ethers path
        const { Contract } = await import('ethers');
        const tokenContract = new Contract(config.aioToken, AIOERC20ABI as any, provider as any);
        const balance = await tokenContract.balanceOf(config.aioRewardPool);
        const balanceBigInt = BigInt(balance.toString());

        if (balanceBigInt < amount) {
          checks.push({
            name: '奖励池余额',
            passed: false,
            message: `奖励池余额不足: ${balanceBigInt.toString()} < ${amount.toString()}`,
            details: {
              balance: balanceBigInt.toString(),
              required: amount.toString(),
              shortfall: (amount - balanceBigInt).toString(),
            },
          });
          suggestions.push(`需要向奖励池充值至少 ${amount.toString()} wei 的 AIO Token`);
        } else {
          checks.push({
            name: '奖励池余额',
            passed: true,
            message: `奖励池余额充足: ${balanceBigInt.toString()} >= ${amount.toString()}`,
            details: {
              balance: balanceBigInt.toString(),
              required: amount.toString(),
            },
          });
        }
      }
    } catch (error: any) {
      checks.push({
        name: '奖励池余额',
        passed: false,
        message: `无法检查奖励池余额: ${error.message}`,
      });
      suggestions.push('检查 AIO Token 合约地址是否正确');
    }

    // 检查 5: Interaction 合约的授权额度
    try {
      if (isViemProvider(provider)) {
        const { createPublicClient, http } = await import('viem');
        const publicClient = createPublicClient({
          transport: http(),
          chain: (provider as any).chain || undefined,
        });

        const allowance = await publicClient.readContract({
          address: config.aioToken as `0x${string}`,
          abi: AIOERC20ABI as any,
          functionName: 'allowance',
          args: [
            config.aioRewardPool as `0x${string}`,
            interactionAddress as `0x${string}`,
          ],
        }) as bigint;

        if (allowance < amount) {
          checks.push({
            name: '授权额度',
            passed: false,
            message: `Interaction 合约授权额度不足: ${allowance.toString()} < ${amount.toString()}`,
            details: {
              allowance: allowance.toString(),
              required: amount.toString(),
              shortfall: (amount - allowance).toString(),
            },
          });
          suggestions.push(`需要从奖励池地址调用 approve(${interactionAddress}, ${amount.toString()}) 或更大的额度`);
        } else {
          checks.push({
            name: '授权额度',
            passed: true,
            message: `授权额度充足: ${allowance.toString()} >= ${amount.toString()}`,
            details: {
              allowance: allowance.toString(),
              required: amount.toString(),
            },
          });
        }
      } else {
        // Ethers path
        const { Contract } = await import('ethers');
        const tokenContract = new Contract(config.aioToken, AIOERC20ABI as any, provider as any);
        const allowance = await tokenContract.allowance(config.aioRewardPool, interactionAddress);
        const allowanceBigInt = BigInt(allowance.toString());

        if (allowanceBigInt < amount) {
          checks.push({
            name: '授权额度',
            passed: false,
            message: `Interaction 合约授权额度不足: ${allowanceBigInt.toString()} < ${amount.toString()}`,
            details: {
              allowance: allowanceBigInt.toString(),
              required: amount.toString(),
              shortfall: (amount - allowanceBigInt).toString(),
            },
          });
          suggestions.push(`需要从奖励池地址调用 approve(${interactionAddress}, ${amount.toString()}) 或更大的额度`);
        } else {
          checks.push({
            name: '授权额度',
            passed: true,
            message: `授权额度充足: ${allowanceBigInt.toString()} >= ${amount.toString()}`,
            details: {
              allowance: allowanceBigInt.toString(),
              required: amount.toString(),
            },
          });
        }
      }
    } catch (error: any) {
      checks.push({
        name: '授权额度',
        passed: false,
        message: `无法检查授权额度: ${error.message}`,
      });
      suggestions.push('检查 AIO Token 合约地址是否正确');
    }

    // 检查 6: 金额不能为零
    if (amount === 0n) {
      checks.push({
        name: '领取金额',
        passed: false,
        message: '领取金额不能为零',
      });
      suggestions.push('请设置一个大于零的领取金额');
    } else {
      checks.push({
        name: '领取金额',
        passed: true,
        message: `领取金额: ${amount.toString()} wei`,
      });
    }

    // 汇总结果
    const allChecksPassed = checks.every(check => check.passed);

    if (allChecksPassed) {
      suggestions.push('所有检查都通过，如果仍然失败，可能是网络问题或合约执行时的其他错误');
    }

    return { allChecksPassed, checks, suggestions };
  } catch (error: any) {
    checks.push({
      name: '诊断过程',
      passed: false,
      message: `诊断过程中发生错误: ${error.message}`,
    });
    suggestions.push('请检查网络连接和合约地址');
    return { allChecksPassed: false, checks, suggestions };
  }
}

/**
 * 检测 Provider 类型
 */
function isViemProvider(provider: any): boolean {
  return typeof provider.request === 'function';
}

