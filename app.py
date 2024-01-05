
import os
import requests
import datetime
from flask import Flask, render_template

app = Flask(__name__)

@app.route('/')
def home():
    # Get the public IP of the server
    ip = requests.get('https://api.ipify.org').text
    date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    # Read the image URL from an environment variable
    return render_template('index.html', image_url=os.getenv('IMAGE_URL'), ip=ip, date=date)

if __name__ == '__main__':
    app.run()
