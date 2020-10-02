staked = {
    "lastBlock": 0,
    "stakedHIPPO": 10,
    "rewards": 0
}

start_block = 0
rewardPerBlock = 10
totalStakedAmount = 10

for current in range(125, 130):
    # current = 130
    lastBlock = staked['lastBlock']
    if lastBlock < start_block:
        lastBlock = start_block
    rewardBlocks = current - lastBlock
    hippoRewards = rewardPerBlock * rewardBlocks / totalStakedAmount * staked['stakedHIPPO']
    staked['rewards'] = staked['rewards'] + hippoRewards
    staked['lastBlock'] = current
    print(current, staked['rewards'])

    totalStakedAmount += 1;


# print("\n")

# staked = {
#     "lastBlock": 50,
#     "stakedHIPPO": 10,
#     "rewards": 0
# }


# totalStakedAmount = 10;
# for current in range(125, 140):
#     # current = 130
#     lastBlock = staked['lastBlock']
#     if lastBlock < start_block:
#         lastBlock = start_block
#     if current < start_block:
#         lastBlock = current
#     rewardBlocks = current - lastBlock
#     hippoRewards = rewardPerBlock * rewardBlocks / totalStakedAmount * staked['stakedHIPPO']
#     print(current, staked['rewards'] + hippoRewards)
#     totalStakedAmount += 1;
