import requests
import asyncio

@asyncio.coroutine
def pokemon(name: str) -> dict:
    url = f"https://pokeapi.co/api/v2/pokemon/{name}"
    response = yield from requests.get(url)
    pokemon_data = response.json()

    img_url = pokemon_data["sprites"]["front_default"]
    img_res = yield from requests.get(img_url)
    pokemon_data['img'] = img_res
    return pokemon_data
