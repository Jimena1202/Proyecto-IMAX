--Rol
CREATE TABLE rol (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT
);

-- Usuario
CREATE TABLE usuario (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    telefono VARCHAR(20),
    fecha_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Usuario-rol 
CREATE TABLE usuario_rol (
    usuario_id INT NOT NULL,
    rol_id INT NOT NULL,
    PRIMARY KEY (usuario_id, rol_id),
    FOREIGN KEY (usuario_id) REFERENCES usuario(id),
    FOREIGN KEY (rol_id) REFERENCES rol(id)
);

-- Metodo pago
CREATE TABLE metodo_pago (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    tipo VARCHAR(30) NOT NULL
);

-- Pelicula
CREATE TABLE pelicula (
    id SERIAL PRIMARY KEY,
    titulo VARCHAR(200) NOT NULL,
    sinopsis TEXT,
    clasificacion VARCHAR(10) NOT NULL,
    duracion_min INT NOT NULL CHECK (duracion_min > 0),
    genero VARCHAR(50),
    poster_url VARCHAR(500),
    activa BOOLEAN NOT NULL DEFAULT TRUE
);

-- Sala
CREATE TABLE sala (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ubicacion VARCHAR(200) NOT NULL,
    capacidad INT NOT NULL CHECK (capacidad > 0),
    mapa_config JSONB
);

-- Asiento
CREATE TABLE asiento (
    id SERIAL PRIMARY KEY,
    sala_id INT NOT NULL,
    fila VARCHAR(5) NOT NULL,
    columna INT NOT NULL,
    zona VARCHAR(50),
    tipo VARCHAR(30),
    FOREIGN KEY (sala_id) REFERENCES sala(id),
    UNIQUE (sala_id, fila, columna)
);

-- Funcion
CREATE TABLE funcion (
    id SERIAL PRIMARY KEY,
    pelicula_id INT NOT NULL,
    sala_id INT NOT NULL,
    fecha_hora_inicio TIMESTAMP NOT NULL,
    fecha_hora_fin TIMESTAMP NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'activa',
    precio_base NUMERIC(10,2) NOT NULL CHECK (precio_base >= 0),
    FOREIGN KEY (pelicula_id) REFERENCES pelicula(id),
    FOREIGN KEY (sala_id) REFERENCES sala(id),
    CHECK (fecha_hora_fin > fecha_hora_inicio)
);

-- Tarifa
CREATE TABLE tarifa (
    id SERIAL PRIMARY KEY,
    funcion_id INT NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    precio NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
    condiciones TEXT,
    FOREIGN KEY (funcion_id) REFERENCES funcion(id)
);

-- Promocion
CREATE TABLE promocion (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    condiciones TEXT,
    descuento NUMERIC(10,2) NOT NULL CHECK (descuento >= 0)
);

-- Transaccion 
CREATE TABLE transaccion (
    id SERIAL PRIMARY KEY,
    usuario_id INT NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto_total NUMERIC(12,2) NOT NULL CHECK (monto_total >= 0),
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente',
    FOREIGN KEY (usuario_id) REFERENCES usuario(id)
);

-- Pago
CREATE TABLE pago (
    id SERIAL PRIMARY KEY,
    transaccion_id INT NOT NULL,
    metodo_pago_id INT NOT NULL,
    monto NUMERIC(12,2) NOT NULL CHECK (monto >= 0),
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente',
    referencia VARCHAR(100),
    FOREIGN KEY (transaccion_id) REFERENCES transaccion(id),
    FOREIGN KEY (metodo_pago_id) REFERENCES metodo_pago(id)
);

