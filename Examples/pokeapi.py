import requests
import asyncio
from views import Image, VStack, Text
from dataclasses import dataclass

@dataclass
class Pokemon:
    name: str
    image: Image
    hp: int
    attack: int
    defense: int
    speed: int
    
    @property
    def __view__(self):
        return VStack([
            Text(self.name),
            self.image,
            Text(f"hp: {self.hp}"),
            Text(f"attack: {self.attack}"),
            Text(f"defense: {self.defense}"),
            Text(f"speed: {self.speed}")
        ]).__view__

@asyncio.coroutine
def pokemon(name: str) -> Pokemon:
    url = f"https://pokeapi.co/api/v2/pokemon/{name}"
    response = yield from requests.get(url)
    pokemon_data = response.json()
    
    img_url = pokemon_data["sprites"]["front_default"]
    img_res = yield from requests.get(img_url)

    def get_stat(name: str) -> int:
        for stat in pokemon_data['stats']:
            if stat['stat']['name'] == name:
                return stat['base_stat']
        return None

    pokemon = Pokemon(
        name=pokemon_data['name'],
        image=Image(img_res.content),
        hp=get_stat('hp'),
        attack=get_stat('attack'),
        defense=get_stat('defense'),
        speed=get_stat('speed')
    )

    return pokemon
