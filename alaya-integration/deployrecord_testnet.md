
🚀 开始实际部署...
[⠊] Compiling...
No files changed, compilation skipped
Script ran successfully.

== Logs ==
  === Deployment Configuration ===
  Deployer: 0x45b0dEB4E7f4B4A3B31321d44a7dE4d0406A45cf
  Safe Multisig (Owner - ALL CONTRACTS): 0x49018A330D59A2bBEdcF2728f34b760EaC644bBe
  Project Wallet: 0x45b0dEB4E7f4B4A3B31321d44a7dE4d0406A45cf
  ================================
  NOTE: All contracts will be owned by Safe multisig from deployment.
  No transferOwnership needed - owner is set in constructor.
  Deploying AIOERC20...
  AIOERC20 deployed at: 0x7a1d1F7Cb42997E3cCc32E69BD26BEbe33ef8F57
  AIOERC20 owner (from constructor): 0x49018A330D59A2bBEdcF2728f34b760EaC644bBe
  
=== IMPORTANT: Initial Mint Required ===
  Initial mint is NOT performed during deployment.
  After deployment, you MUST mint tokens through Safe multisig:
    1. Go to Safe multisig interface
    2. Create a new transaction
    3. Call: aioToken.mint(projectWallet, amount)
    4. Or use Mint.s.sol script with Safe multisig private key
  Token Address: 0x7a1d1F7Cb42997E3cCc32E69BD26BEbe33ef8F57
  Project Wallet: 0x45b0dEB4E7f4B4A3B31321d44a7dE4d0406A45cf
  Recommended Initial Mint Amount (without decimals): 100000000
  ========================================

  Deploying FeeDistributor...
  FeeDistributor deployed at: 0xA928B7Ab1f6d3B15C11b01d83680199bAb028BA9
  FeeDistributor owner (from constructor): 0x49018A330D59A2bBEdcF2728f34b760EaC644bBe
  Deploying Interaction...
  Interaction deployed at: 0x5e9f531503322b77c6AA492Ef0b3410C4Ee8CF47
  Interaction owner (from constructor): 0x49018A330D59A2bBEdcF2728f34b760EaC644bBe
  Deploying GovernanceBootstrapper...
  GovernanceBootstrapper deployed at: 0xe453d4fc118A07B0e0f0AdF39cE1A103AA8cd197
  GovernanceBootstrapper is stateless (no owner)
  
=== Ownership Verification ===
  [OK] All contracts owned by Safe multisig: 0x49018A330D59A2bBEdcF2728f34b760EaC644bBe
  [OK] No transferOwnership needed - ownership set in constructor
  =============================
  === Deployment Addresses ===
  {
  "aioToken": "0x7a1d1F7Cb42997E3cCc32E69BD26BEbe33ef8F57",
  "feeDistributor": "0xA928B7Ab1f6d3B15C11b01d83680199bAb028BA9",
  "interaction": "0x194B90670ba16E5ceF54A595e56b8157962c2E88",
  "governanceBootstrapper": "0xe453d4fc118A07B0e0f0AdF39cE1A103AA8cd197",
  "safeMultisig": "0x49018A330D59A2bBEdcF2728f34b760EaC644bBe",
  "network": "unknown"
}

  === End Deployment Addresses ===

## Setting up 1 EVM.

==========================

Chain 84532

Estimated gas price: 0.001483749 gwei

Estimated total gas used for script: 7221452

Estimated amount required: 0.000010714822183548 ETH

==========================

##### base-sepolia
✅  [Success] Hash: 0xddd4fe7c5792b0e31785947e84a72497e10cceae99d9f8cfd0d3a97a5b5d30e7
Contract Address: 0xe453d4fc118A07B0e0f0AdF39cE1A103AA8cd197
Block: 33981961
Paid: 0.000000778201360384 ETH (626192 gas * 0.001242752 gwei)


##### base-sepolia
✅  [Success] Hash: 0xf4f96b5cbcd894b0cc3227e0bbd429cab9fca2731c4809f4860c4b3a10ccad65
Contract Address: 0xA928B7Ab1f6d3B15C11b01d83680199bAb028BA9
Block: 33981960
Paid: 0.000001591194205896 ETH (1280833 gas * 0.001242312 gwei)


##### base-sepolia
✅  [Success] Hash: 0xdf25a743ea16f329fd094b96235bed581712222196493eee2d3dd0ffb9ab9630
Contract Address: 0x5e9f531503322b77c6AA492Ef0b3410C4Ee8CF47
Block: 33981961
Paid: 0.000002577201699072 ETH (2073786 gas * 0.001242752 gwei)


##### base-sepolia
✅  [Success] Hash: 0x719aa7e7e1d37a2f450ff48b1b4aa38e4cff4ffd6c2f701c1ba57ea23545b454
Contract Address: 0x7a1d1F7Cb42997E3cCc32E69BD26BEbe33ef8F57
Block: 33981960
Paid: 0.000001955590404048 ETH (1574154 gas * 0.001242312 gwei)

✅ Sequence #1 on base-sepolia | Total Paid: 0.0000069021876694 ETH (5554965 gas * avg 0.001242532 gwei)
                                                                                

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: /Users/senyang/project/alaya-integration/broadcast/Deploy.s.sol/84532/run-latest.json

Sensitive values saved to: /Users/senyang/project/alaya-integration/cache/Deploy.s.sol/84532/run-latest.json


✅ 部署完成！

=== 部署地址 ===
请查看上方的 JSON 输出获取所有合约地址

部署的合约包括:
  - AIOERC20: AIO 代币合约
  - FeeDistributor: 手续费分配合约
  - Interaction: 交互合约
  - GovernanceBootstrapper: 治理引导合约

所有合约的所有者都是: 0x49018A330D59A2bBEdcF2728f34b760EaC644bBe
==================

🔍 验证合约所有权...
（此步骤需要从部署输出中获取合约地址）
可以使用以下命令验证:

  # 检查 AIOERC20 所有者
  cast call <AIO_TOKEN_ADDRESS> "owner()(address)" --rpc-url https://base-sepolia.g.alchemy.com/v2/Br9B6PkCm4u7NhukuwdGihx6SZnhrLWI

  # 检查 FeeDistributor 所有者
  cast call <FEE_DISTRIBUTOR_ADDRESS> "owner()(address)" --rpc-url https://base-sepolia.g.alchemy.com/v2/Br9B6PkCm4u7NhukuwdGihx6SZnhrLWI

  # 检查 Interaction 所有者
  cast call <INTERACTION_ADDRESS> "owner()(address)" --rpc-url https://base-sepolia.g.alchemy.com/v2/Br9B6PkCm4u7NhukuwdGihx6SZnhrLWI

📝 后续步骤:
1. ✅ 保存所有合约地址（从上方 JSON 输出中获取）
2. ⚠️  手动在 Basescan 上验证合约（如果自动验证失败）
3. 📖 配置 AIO Token 和奖励池（见 DEPLOY_BASE_TESTNET.md 的'部署后操作'部分）
4. 🧪 测试合约功能

重要提示:
  - 所有合约的所有者都是 Safe 多签地址: 0x49018A330D59A2bBEdcF2728f34b760EaC644bBe
  - 后续配置操作需要通过 Safe 多签执行
  - 参考 DEPLOY_BASE_TESTNET.md 了解详细配置步骤
(base) senyang@sendeMacBook-Pro scripts % 