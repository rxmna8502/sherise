import requests
payload = {"name":"Test User","email":"test@example.com","phone":"9999999999","address":"Test","gender":"F"}
resp = requests.post('http://127.0.0.1:10201/api/register', json=payload, timeout=10)
print(resp.status_code)
print(resp.text)
