import os
import requests
from dotenv import load_dotenv
load_dotenv()

key = os.getenv('NEWSAPI_KEY')
print(f"Key loaded: {bool(key)}")
url = "https://newsapi.org/v2/top-headlines?country=tr&apiKey=" + key
print(f"Requesting: {url.replace(key, 'HIDDEN')}")
r = requests.get(url)
print(f"Status: {r.status_code}")
print(f"Body: {r.text[:500]}")
