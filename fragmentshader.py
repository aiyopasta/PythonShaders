# By Aditya Abhyankar, September 2022
# Purpose: To create a simple quad the size of the window (like ShaderToy)
#          and create fun designs entirely using the fragment shader.

import glfw  # library for creating window, event handling, etc. (other alternative is GLUT)
from OpenGL.GL import *
from OpenGL.GL.shaders import compileProgram, compileShader
import numpy as np
import time


def readall(filename:str):
    with open(filename) as f:
        lines = f.read()  # reads entire file as 1 string
        return lines


# Vertex and Fragment Shader Programs (TODO: Change implementation to read them from different files.)
vertex_src = readall('vert.glsl')
fragment_src = readall('frag.glsl')


# Resize OpenGL Viewport to match window size
def window_resize(window, width, height):
    glViewport(0, 0, width, height)


# Initialize glfw and create the window
if not glfw.init():
    raise Exception("glfw didn't get initialized!")

# Extra 4 lines because of MacOS
glfw.window_hint(glfw.CONTEXT_VERSION_MAJOR, 4)
glfw.window_hint(glfw.CONTEXT_VERSION_MINOR, 1)
glfw.window_hint(glfw.OPENGL_FORWARD_COMPAT, GL_TRUE)
glfw.window_hint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
window = glfw.create_window(1920, 1080, "Hello OpenGL!", None, None)
if not window:
    glfw.terminate()
    raise Exception("glfw window cannot be created!")

# Set window's position
glfw.set_window_pos(window, 0, 0)

# Set the callback function for window resize
glfw.set_window_size_callback(window, window_resize)

# Make context current
glfw.make_context_current(window)
VAO = glGenVertexArrays(1)
glBindVertexArray(VAO)

# Note: Each entry is a 32-bit float, so 32/8 = 4 bytes total.
# Since each vertex's data has 6 elements (3 coordinates + RGB) in total each vertex data is 6*4 = 24 bytes.
vertex_data = [-1.0, -1.0, 0.0, 1.0, 0.0, 0.0,
                1.0, -1.0, 0.0, 0.0, 1.0, 0.0,
               -1.0,  1.0, 0.0, 0.0, 0.0, 1.0,
                1.0,  1.0, 0.0, 1.0, 1.0, 1.0]

vertex_data = np.array(vertex_data, dtype=np.float32)

# The actual shader program
shader = compileProgram(compileShader(vertex_src, GL_VERTEX_SHADER), compileShader(fragment_src, GL_FRAGMENT_SHADER))

# Gets an ID for the VBO buffer (which is a place where the vertex data will be stored on the GPU)
VBO_ID = glGenBuffers(1)

# Represents the intent to use our VBO for vertex attribute data
glBindBuffer(GL_ARRAY_BUFFER, VBO_ID)

# Actually store our vertex data in our VBO
# IMPORTANT: USE GL_STATIC_DRAW IF VBO CONTENTS WILL BE MODIFIED REPEATEDLY
# (i.e. You're gonna use glBufferSubData in the game loop to modify the vertices on the CPU!)
glBufferData(GL_ARRAY_BUFFER, vertex_data.nbytes, vertex_data, GL_STATIC_DRAW)

# 1. First, send the positions of the vertices.
position_idx = glGetAttribLocation(shader, "a_position")  # It is 0
glEnableVertexAttribArray(position_idx)
glVertexAttribPointer(position_idx, 3, GL_FLOAT, GL_FALSE, 24, ctypes.c_void_p(0))  # Size = 3 bytes, Stride = 24, offset = 0

# 2. Second, send the colors of the vertices.
color_idx = glGetAttribLocation(shader, "a_color")  # It is 1
glEnableVertexAttribArray(color_idx)
glVertexAttribPointer(color_idx, 3, GL_FLOAT, GL_FALSE, 24, ctypes.c_void_p(12))  # Start at byte 12 and keep reading 3 floats at 24 entry intervals

# 3. Send the uniform time variable.
uniform_idx = glGetUniformLocation(shader, "time")

# Tells OpenGL to use our shader program.
glUseProgram(shader)
glClearColor(0, 0.1, 0.1, 1)  # Sets background color

# The main game loop
start = time.time()
while not glfw.window_should_close(window):
    glfw.poll_events()  # makes application responsive
    glClear(GL_COLOR_BUFFER_BIT)  # Clears the colors buffer
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)  # Draw the quad (the 4 vertices from 0 to 3 inclusive)
    glUniform1f(uniform_idx, time.time() - start)
    glfw.swap_buffers(window)  # makes the background buffer in which you've drawn new stuff visible

# terminate glfw, free up allocated resources
glfw.terminate()
