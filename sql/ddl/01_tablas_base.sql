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
