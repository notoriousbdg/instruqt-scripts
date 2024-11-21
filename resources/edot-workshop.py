from flask import Flask

import context
import assistant



app = Flask(__name__)


def init():

    assistant.load()
    context.load()
    
init()
