import pytest

@pytest.fixture
def onchain_contract(accounts, Onchain):
    yield Onchain.deploy({'from': accounts[0]})


def test_mint(accounts, onchain_contract):
    assert onchain_contract.mint()
    assert onchain_contract.tokenURI(0) == 'miau'
    assert onchain_contract.ownerOf(0) == accounts[0]