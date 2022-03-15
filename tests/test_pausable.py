import pytest

@pytest.fixture
def onchain_contract(accounts, Onchain):
    yield Onchain.deploy({'from': accounts[0]})


def test_ownable_status(accounts, onchain_contract):
    assert onchain_contract.contractStatus() == False
    onchain_contract.pause()
    assert onchain_contract.contractStatus() == True
