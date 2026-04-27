import os
from flask import Flask, request

app = Flask(__name__)

STYLE = """
<style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f7f9; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
    .card { background: white; padding: 2rem; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); width: 100%; max-width: 400px; text-align: center; }
    h1 { color: #2c3e50; margin-bottom: 1.5rem; }
    input[type="password"] { width: 100%; padding: 12px; margin: 10px 0; border: 1px solid #ddd; border-radius: 6px; box-sizing: border-box; }
    input[type="submit"] { background-color: #3498db; color: white; border: none; padding: 12px 20px; border-radius: 6px; cursor: pointer; width: 100%; font-size: 16px; transition: background 0.3s; }
    input[type="submit"]:hover { background-color: #2980b9; }
    .debug { font-size: 12px; color: #7f8c8d; margin-top: 20px; border-top: 1px solid #eee; padding-top: 10px; }
    .success { color: #27ae60; font-weight: bold; }
    .error { color: #e74c3c; font-weight: bold; }
</style>
"""

@app.route('/')
def index():
    env_name = os.getenv('ENV_NAME', 'K8s Klaszter')
    return f'''
    {STYLE}
    <div class="card">
        <h1>{env_name}</h1>
        <form action="/login" method="post">
            <input type="password" name="password" placeholder="Add meg a titkos jelszót...">
            <input type="submit" value="Belépés a rendszerbe">
        </form>
    </div>
    '''

@app.route('/login', methods=['POST'])
def login():
    correct_pass = os.getenv('SECRET_DATA', '')
    user_input = request.form.get('password')
    
    status_msg = ""
    if user_input == correct_pass and correct_pass != '':
        status_msg = '<h2 class="success">Sikeres belépés!</h2><p>A Kubernetes Secret érvényes.</p>'
    else:
        status_msg = '<h2 class="error">Hiba!</h2><p>Helytelen jelszó vagy hiányzó Secret.</p>'

    return f'{STYLE}<div class="card">{status_msg}<br><a href="/" style="color: #3498db; text-decoration: none;">Vissza</a></div>'

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)