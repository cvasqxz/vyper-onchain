import pytest
from brownie import convert

@pytest.fixture
def onchain_contract(accounts, Onchain):
    yield Onchain.deploy({'from': accounts[0]})


def test_owner(accounts, onchain_contract):
    assert onchain_contract.owner() == accounts[0]

    onchain_contract.transferOwnership(accounts[1], {'from': accounts[0]})
    assert onchain_contract.owner() == accounts[1]
    
    onchain_contract.renounceOwnership({'from': accounts[1]})
    assert onchain_contract.owner() == convert.to_address("0x0000000000000000000000000000000000000000")
