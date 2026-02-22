from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    return '<h1>Wiz Lab - Robert Irwin</h1><p><a href="/wizexercise.txt">wizexercise.txt</a></p>'

@app.route('/wizexercise.txt')
def exercise():
    with open('wizexercise.txt', 'r') as f:
        return f.read(), 200, {'Content-Type': 'text/plain'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
