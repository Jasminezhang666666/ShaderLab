// setup canvas and webgl context
const canvas = document.getElementById('glcanvas');
const gl = canvas.getContext('webgl');

if (!gl) {
    alert('your browser does not support webgl');
}

// define the screen quad
const vertices = new Float32Array([
    -1, -1,  
     1, -1, 
    -1,  1,
    -1,  1, 
     1, -1, 
     1,  1,
]);

// buffer setup (sending data to gpu)
const buffer = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);

// shader compilation helper
function createShader(gl, type, sourceId) {
    const source = document.getElementById(sourceId).textContent;
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    
    // check for compile errors (syntax errors in glsl)
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        console.error('shader compile error:', gl.getShaderInfoLog(shader));
        gl.deleteShader(shader);
        return null;
    }
    return shader;
}

// compile both parts of the program
const vertShader = createShader(gl, gl.VERTEX_SHADER, 'vertex-shader');
const fragShader = createShader(gl, gl.FRAGMENT_SHADER, 'fragment-shader');
const program = gl.createProgram();

gl.attachShader(program, vertShader);
gl.attachShader(program, fragShader);
gl.linkProgram(program);

if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.error('program link error:', gl.getProgramInfoLog(program));
}

gl.useProgram(program);

// tell webgl how to pull data from the buffer into the 'position' attribute
const positionLoc = gl.getAttribLocation(program, 'position');
gl.enableVertexAttribArray(positionLoc);
gl.vertexAttribPointer(positionLoc, 2, gl.FLOAT, false, 0, 0);

// set variables
const uResLoc = gl.getUniformLocation(program, 'uResolution');
const uTimeLoc = gl.getUniformLocation(program, 'uTime');

// render loop
function render(time) {
    // convert time to seconds
    time *= 0.001; 

    // handle window resize
    if (canvas.width !== canvas.clientWidth || canvas.height !== canvas.clientHeight) {
        canvas.width = canvas.clientWidth;
        canvas.height = canvas.clientHeight;
        gl.viewport(0, 0, canvas.width, canvas.height);
    }

    // pass values to the shader
    gl.uniform2f(uResLoc, canvas.width, canvas.height);
    gl.uniform1f(uTimeLoc, time);

    // draw the 6 vertices (2 triangles)
    gl.drawArrays(gl.TRIANGLES, 0, 6);

    // request the next frame
    requestAnimationFrame(render);
}

// start the loop
requestAnimationFrame(render);