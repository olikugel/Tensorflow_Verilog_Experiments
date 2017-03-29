#From https://github.com/tensorflow/tensorflow/issues/1287

import os
import os.path
import tensorflow as tf
from tensorflow.python.platform import gfile
import getopt
import sys

GRAPH_FILE = '/media/visiting/0968dcdd-0d87-49b2-af5b-2ba142d8dcec/Uniproject/Graphs/tensorflow_inception_graph.pb'
LOG_DIR = '/tmp/inception_logdir'

options, _ = getopt.getopt(sys.argv[1:], 'g:l:', ['graph=','logdir='])

for opt, arg in options: # opt is key, arg is value. opt is the option, arg is the value for the option.
    if opt in ('-g', '--graph'):
        GRAPH_FILE = arg
    if opt in ('-l', '--logdir'):
        LOG_DIR = arg

print('Graph file: ', GRAPH_FILE)
print('Log directory: ', LOG_DIR)

if not os.path.exists(LOG_DIR):
    os.makedirs(LOG_DIR)
with tf.Session() as sess:
    model_filename = GRAPH_FILE
    with gfile.FastGFile(model_filename, 'rb') as f:
        graph_def = tf.GraphDef()
        graph_def.ParseFromString(f.read())
        _ = tf.import_graph_def(graph_def, name='')
    # writer = tf.summary.FileWriter(LOG_DIR, graph_def)
    writer = tf.summary.FileWriter(LOG_DIR, sess.graph)
    writer.close()
