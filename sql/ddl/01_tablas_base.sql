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

-- Boleto
CREATE TABLE boleto (
    id SERIAL PRIMARY KEY,
    funcion_id INT NOT NULL,
    asiento_id INT NOT NULL,
    usuario_id INT NOT NULL,
    transaccion_id INT,
    estado VARCHAR(20) NOT NULL DEFAULT 'reservado',
    precio_final NUMERIC(10,2) NOT NULL CHECK (precio_final >= 0),
    FOREIGN KEY (funcion_id) REFERENCES funcion(id),
    FOREIGN KEY (asiento_id) REFERENCES asiento(id),
    FOREIGN KEY (usuario_id) REFERENCES usuario(id),
    FOREIGN KEY (transaccion_id) REFERENCES transaccion(id)
);

-- QR
CREATE TABLE qr (
    id SERIAL PRIMARY KEY,
    boleto_id INT NOT NULL UNIQUE,
    codigo VARCHAR(100) NOT NULL UNIQUE,
    usado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_uso TIMESTAMP,
    FOREIGN KEY (boleto_id) REFERENCES boleto(id)
);

ALTER TABLE boleto
    ADD CONSTRAINT chk_boleto_precio_positivo
    CHECK (precio_final > 0);

-- Boleto válido
ALTER TABLE boleto
    ADD CONSTRAINT chk_boleto_estado
    CHECK (estado IN ('reservado', 'pagado', 'cancelado', 'usado'));

-- Transacción válida
ALTER TABLE transaccion
    ADD CONSTRAINT chk_transaccion_estado
    CHECK (estado IN ('pendiente', 'aprobada', 'rechazada', 'cancelada'));

-- Pago válido
ALTER TABLE pago
    ADD CONSTRAINT chk_pago_estado
    CHECK (estado IN ('pendiente', 'aprobado', 'rechazado'));

-- Búsqueda de funciones por película y fecha
CREATE INDEX idx_funcion_pelicula_fecha
ON funcion(pelicula_id, fecha_hora_inicio);

-- Búsqueda de funciones por sala y fecha
CREATE INDEX idx_funcion_sala_fecha
ON funcion(sala_id, fecha_hora_inicio);

-- Búsqueda de asientos por sala (para mapa)
CREATE INDEX idx_asiento_sala
ON asiento(sala_id);

-- Búsqueda de boletos por función y asiento (para disponibilidad)
CREATE INDEX idx_boleto_funcion_asiento
ON boleto(funcion_id, asiento_id);

-- Búsqueda de boletos por usuario (para "mis entradas")
CREATE INDEX idx_boleto_usuario
ON boleto(usuario_id);

-- Búsqueda de QR por código (para escaneo en puerta)
CREATE INDEX idx_qr_codigo
ON qr(codigo);

-- Búsqueda de transacciones por usuario y fecha
CREATE INDEX idx_transaccion_usuario_fecha
ON transaccion(usuario_id, fecha);

-- Transacciones 
CREATE TABLE transaccion_log (
    id BIGSERIAL PRIMARY KEY,
    transaccion_id INT NOT NULL,
    evento VARCHAR(50) NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    datos JSONB,
    FOREIGN KEY (transaccion_id) REFERENCES transaccion(id)
);

-- Bloqueos y estados de asientos
CREATE TABLE asiento_auditoria_log (
    id BIGSERIAL PRIMARY KEY,
    asiento_id INT NOT NULL,
    funcion_id INT NOT NULL,
    usuario_id INT,
    accion VARCHAR(50) NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (asiento_id) REFERENCES asiento(id),
    FOREIGN KEY (funcion_id) REFERENCES funcion(id),
    FOREIGN KEY (usuario_id) REFERENCES usuario(id)
);

-- Accesos en puerta
CREATE TABLE acceso_puerta_log (
    id BIGSERIAL PRIMARY KEY,
    boleto_id INT NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    puerta VARCHAR(50),
    resultado VARCHAR(30) NOT NULL,
    operador_id INT,
    FOREIGN KEY (boleto_id) REFERENCES boleto(id),
    FOREIGN KEY (operador_id) REFERENCES usuario(id)
);

-- Auditoría administrativa
CREATE TABLE admin_operacion_audit (
    id BIGSERIAL PRIMARY KEY,
    admin_id INT NOT NULL,
    accion VARCHAR(100) NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip VARCHAR(45),
    detalles JSONB,
    FOREIGN KEY (admin_id) REFERENCES usuario(id)
);

-- Índices auditoría
CREATE INDEX idx_transaccion_log_fecha ON transaccion_log(fecha);
CREATE INDEX idx_asiento_auditoria_log_fecha ON asiento_auditoria_log(fecha);
CREATE INDEX idx_acceso_puerta_log_fecha ON acceso_puerta_log(fecha);
CREATE INDEX idx_admin_operacion_audit_fecha ON admin_operacion_audit(fecha);

-- Roles
CREATE ROLE rol_cliente NOLOGIN;
CREATE ROLE rol_taquillero NOLOGIN;
CREATE ROLE rol_operador_puerta NOLOGIN;
CREATE ROLE rol_contador NOLOGIN;
CREATE ROLE rol_administrador NOLOGIN;

-- Lectura de cartelera, compra
GRANT SELECT ON pelicula, funcion, sala, asiento, tarifa TO rol_cliente;
GRANT SELECT, INSERT ON transaccion, pago, boleto TO rol_cliente;
GRANT SELECT ON qr TO rol_cliente;

-- Venta presencial
GRANT SELECT ON pelicula, funcion, sala, asiento, tarifa TO rol_taquillero;
GRANT SELECT, INSERT ON transaccion, pago, boleto TO rol_taquillero;
GRANT SELECT ON qr TO rol_taquillero;

-- Validar QR
GRANT SELECT ON boleto, qr TO rol_operador_puerta;
GRANT INSERT ON acceso_puerta_log TO rol_operador_puerta;

-- Reportes financieros
GRANT SELECT ON transaccion, pago, boleto, metodo_pago TO rol_contador;
GRANT SELECT ON transaccion_log TO rol_contador;

-- Control total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO rol_administrador;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rol_administrador;

ALTER TABLE boleto
    ADD COLUMN reservado_hasta TIMESTAMP;

CREATE UNIQUE INDEX idx_boleto_asiento_unico
ON boleto(funcion_id, asiento_id)
WHERE estado IN ('reservado', 'pagado');

-- Encontrar reservas expiradas
CREATE INDEX idx_boleto_reservado_hasta
ON boleto(reservado_hasta)
WHERE estado = 'reservado';

CREATE FUNCTION fn_bloquear_asiento(
    p_funcion_id INT,
    p_asiento_id INT,
    p_usuario_id INT,
    p_precio NUMERIC
) RETURNS INT AS $$
DECLARE
    v_boleto_id INT;
BEGIN
    INSERT INTO boleto (
        funcion_id, asiento_id, usuario_id, estado, precio_final, reservado_hasta
    ) VALUES (
        p_funcion_id, p_asiento_id, p_usuario_id, 'reservado', p_precio,
        CURRENT_TIMESTAMP + INTERVAL '2 minutes'
    )
    RETURNING id INTO v_boleto_id;

    RETURN v_boleto_id;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION fn_liberar_asientos_expirados()
RETURNS INT AS $$
DECLARE
    v_count INT;
BEGIN
    UPDATE boleto
    SET estado = 'cancelado'
    WHERE estado = 'reservado'
      AND reservado_hasta < CURRENT_TIMESTAMP;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;
