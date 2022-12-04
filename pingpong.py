import glfw
from OpenGL.GL import *
from OpenGL.GL.shaders import compileProgram, compileShader
import numpy as np
import time

width, height = 1728, 1051


def readall(filename:str):
    with open(filename) as f:
        lines = f.read()  # reads entire file as 1 string
        return lines

# Vertex and Fragment Shader Programs for rendering
off_vertex_src = readall('vert2.glsl')
off_fragment_src = readall('frag2.glsl')


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
window = glfw.create_window(width, height, "Hello OpenGL!", None, None)
if not window:
    glfw.terminate()
    raise Exception("glfw window cannot be created!")

# Set window's position
glfw.set_window_pos(window, 0, 0)

# Set the callback function for window resize
glfw.set_window_size_callback(window, window_resize)

# Make the new window the current context
glfw.make_context_current(window)

# Create the VAO
VAO = glGenVertexArrays(1)
glBindVertexArray(VAO)

# Note: Each entry is a 32-bit float, so 32/8 = 4 bytes total.
# Since each vertex's data has 8 elements (3 coordinates + 3 RGB + 2 tex coords) in total each vertex data is 8*4 = 32 bytes.
vertex_data = [-1.0, -1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
                1.0, -1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0,
               -1.0,  1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0,
                1.0,  1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0]

vertex_data = np.array(vertex_data, dtype=np.float32)

# The actual shader program for rendering
shader = compileProgram(compileShader(off_vertex_src, GL_VERTEX_SHADER), compileShader(off_fragment_src, GL_FRAGMENT_SHADER))
# Get an ID for the VBO buffer (which is a place where the vertex data will be stored on the GPU)
VBO_ID = glGenBuffers(1)
# Put our VBO into the hotseat, and store our vertex data in it.
glBindBuffer(GL_ARRAY_BUFFER, VBO_ID)
glBufferData(GL_ARRAY_BUFFER, vertex_data.nbytes, vertex_data, GL_STATIC_DRAW)
# 1. Send the positions of the vertices.
position_idx = glGetAttribLocation(shader, "a_position")
glEnableVertexAttribArray(position_idx)
glVertexAttribPointer(position_idx, 3, GL_FLOAT, GL_FALSE, 32, ctypes.c_void_p(0))  # Size = 3 bytes, Stride = 32, offset = 0
# 2. Send the colors of the vertices.
color_idx = glGetAttribLocation(shader, "a_color")
glEnableVertexAttribArray(color_idx)
glVertexAttribPointer(color_idx, 3, GL_FLOAT, GL_FALSE, 32, ctypes.c_void_p(12))  # Start at byte 3*4=12 and keep reading 3 floats every 32 bytes
# 3. Send the tex_coords variable.
tex_coords_idx = glGetAttribLocation(shader, "a_tex_coords")
glEnableVertexAttribArray(tex_coords_idx)
glVertexAttribPointer(tex_coords_idx, 2, GL_FLOAT, GL_FALSE, 32, ctypes.c_void_p(24))  # Start at byte (3+3)*4=12 and keep reading 3 floats every 24 bytes
# 3. Send the uniform time variable.
time_idx = glGetUniformLocation(shader, "time")
# 4. Send the uniform screenTexture variable.
screenTexture_idx = glGetUniformLocation(shader, "screenTexture")
# 5. Send the uniform blah variable.
blah_idx = glGetUniformLocation(shader, "blah")
# 6. Send the uniform n variable.
n_idx = glGetUniformLocation(shader, "n")


# Create and bind FBO1
FBO1 = glGenFramebuffers(1)
glBindFramebuffer(GL_FRAMEBUFFER, FBO1)

# Create the first texture that will be used as a color attachment
color_attachment1 = glGenTextures(1)

# Bind the texture for use as "GL_TEXTURE_2D"
glBindTexture(GL_TEXTURE_2D, color_attachment1)
glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width * 2, height * 2, 0, GL_RGB, GL_UNSIGNED_BYTE, None)

# Set its parameters
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

# Attach it to the first FBO as a color attachment
glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, color_attachment1, 0)

# Check for errors
if glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE:
    raise Exception("Error setting up FBO1!")

# Create and bind FBO2
FBO2 = glGenFramebuffers(1)
glBindFramebuffer(GL_FRAMEBUFFER, FBO2)

# Create the second texture that will be used as a color attachment
color_attachment2 = glGenTextures(1)

# Bind the texture for use as "GL_TEXTURE_2D"
glBindTexture(GL_TEXTURE_2D, color_attachment2)
glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width * 2, height * 2, 0, GL_RGB, GL_UNSIGNED_BYTE, None)

# Set the texture parameters
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

# Attach it to the second FBO as a color attachment
glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, color_attachment2, 0)

# Check for errors
if glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE:
    raise Exception("Error setting up FBO2!")


# Tells OpenGL to use our shader program.
glUseProgram(shader)
glClearColor(0, 0.1, 0.1, 1)  # Sets background color

ping_pong = True
n = 1
start = time.time()
while not glfw.window_should_close(window):
    print(n)
    # 1. Send the correct blah variable, based on value of ping_pong.
    glUniform1i(blah_idx, 1 if ping_pong else 2)
    glUniform1i(n_idx, n)
    glUniform1f(time_idx, time.time() - start)
    # 2. Activate, bind, and send the texture of the previous draw into the fragment shader.
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, color_attachment1 if not ping_pong else color_attachment2)
    glUniform1i(screenTexture_idx, 0)
    # 3. Bind the correct framebuffer, and clear it.
    glBindFramebuffer(GL_FRAMEBUFFER, FBO1 if ping_pong else FBO2)
    glClear(GL_COLOR_BUFFER_BIT)
    # 4. Draw onto that framebuffer.
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)
    # 5. Do everything you did in the while loop for the epilepsy example.
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, color_attachment1 if ping_pong else color_attachment2)   # redundant?
    glUniform1i(screenTexture_idx, 0)
    # Let the fragment shader know to run the code for simply displaying the texture onto the screen.
    glUniform1i(blah_idx, -2394)
    # Bind the default FBO, clear it, and draw on it using our fragment shader.
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    glDisable(GL_DEPTH_TEST)
    glClear(GL_COLOR_BUFFER_BIT)
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)

    # Toggle ping pong, increment n
    ping_pong = not ping_pong
    n += 1

    # The regular stuff
    glfw.swap_buffers(window)
    glfw.poll_events()
    # time.sleep(0.001)

# Clean up
glfw.terminate()