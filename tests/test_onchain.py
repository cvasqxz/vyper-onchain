import pytest
import json


@pytest.fixture
def onchain_contract(accounts, Onchain):
    yield Onchain.deploy({'from': accounts[0]})


def test_mint(accounts, onchain_contract):
    max_supply = onchain_contract.maxSupply()
    for i in range(max_supply):
        assert onchain_contract.mint({'from': accounts[0], 'value': 0.05*1e18})

        tokenURI = onchain_contract.tokenURI(i)
        assert json.loads(tokenURI)['hola'] == 'chao'
        assert onchain_contract.ownerOf(i) == accounts[0]

