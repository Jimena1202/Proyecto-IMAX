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

CREATE FUNCTION fn_confirmar_compra(
    p_transaccion_id INT
) RETURNS INT AS $$
DECLARE
    v_boleto RECORD;
    v_qr_count INT := 0;
    v_codigo VARCHAR(100);
BEGIN
    --Marcar como aprobada
    UPDATE transaccion
    SET estado = 'aprobada'
    WHERE id = p_transaccion_id AND estado = 'pendiente';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transacción % no existe o no está pendiente', p_transaccion_id;
    END IF;

    -- Pagarlo y crear QR
    FOR v_boleto IN
        SELECT id FROM boleto
        WHERE transaccion_id = p_transaccion_id
          AND estado = 'reservado'
    LOOP
        UPDATE boleto
        SET estado = 'pagado',
            reservado_hasta = NULL
        WHERE id = v_boleto.id;

        -- Código único
        v_codigo := 'IMAX-' || p_transaccion_id || '-' || v_boleto.id || '-' ||
                    substr(md5(random()::text), 1, 12);

        INSERT INTO qr (boleto_id, codigo, usado)
        VALUES (v_boleto.id, v_codigo, FALSE);

        v_qr_count := v_qr_count + 1;
    END LOOP;

    -- Registrar log
    INSERT INTO transaccion_log (transaccion_id, evento, datos)
    VALUES (p_transaccion_id, 'COMPRA_APROBADA',
            jsonb_build_object('boletos_qr', v_qr_count));

    RETURN v_qr_count;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION fn_cancelar_compra(
    p_transaccion_id INT,
    p_motivo VARCHAR DEFAULT 'PAGO_RECHAZADO'
) RETURNS INT AS $$
DECLARE
    v_count INT;
BEGIN
    -- Cancelar transacción
    UPDATE transaccion
    SET estado = 'rechazada'
    WHERE id = p_transaccion_id AND estado = 'pendiente';

    -- Liberar boletos reservados
    UPDATE boleto
    SET estado = 'cancelado',
        reservado_hasta = NULL
    WHERE transaccion_id = p_transaccion_id
      AND estado = 'reservado';

    GET DIAGNOSTICS v_count = ROW_COUNT;

    -- Log
    INSERT INTO transaccion_log (transaccion_id, evento, datos)
    VALUES (p_transaccion_id, 'COMPRA_RECHAZADA',
            jsonb_build_object('motivo', p_motivo, 'asientos_liberados', v_count));

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION trg_fn_auditoria_boleto()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO asiento_auditoria_log
            (asiento_id, funcion_id, usuario_id, accion, fecha)
        VALUES
            (NEW.asiento_id, NEW.funcion_id, NEW.usuario_id, 'BLOQUEO', CURRENT_TIMESTAMP);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.estado = 'pagado' AND OLD.estado = 'reservado' THEN
            INSERT INTO asiento_auditoria_log
                (asiento_id, funcion_id, usuario_id, accion, fecha)
            VALUES
                (NEW.asiento_id, NEW.funcion_id, NEW.usuario_id, 'COMPRA', CURRENT_TIMESTAMP);
        ELSIF NEW.estado = 'cancelado' AND OLD.estado = 'reservado' THEN
            INSERT INTO asiento_auditoria_log
                (asiento_id, funcion_id, usuario_id, accion, fecha)
            VALUES
                (NEW.asiento_id, NEW.funcion_id, NEW.usuario_id, 'LIBERACION', CURRENT_TIMESTAMP);
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_boleto
AFTER INSERT OR UPDATE ON boleto
FOR EACH ROW EXECUTE FUNCTION trg_fn_auditoria_boleto();

CREATE FUNCTION trg_fn_proteger_sala()
RETURNS TRIGGER AS $$
DECLARE
    v_ventas INT;
BEGIN
    SELECT COUNT(*) INTO v_ventas
    FROM boleto b
    JOIN funcion f ON f.id = b.funcion_id
    WHERE f.sala_id = OLD.id
      AND b.estado IN ('reservado', 'pagado');

    IF v_ventas > 0 THEN
        RAISE EXCEPTION
        'No se puede modificar la sala % porque tiene % boletos activos',
        OLD.id, v_ventas;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_proteger_sala
BEFORE UPDATE OR DELETE ON sala
FOR EACH ROW EXECUTE FUNCTION trg_fn_proteger_sala();

CREATE FUNCTION fn_check_in_qr(
    p_codigo VARCHAR,
    p_operador_id INT
) RETURNS TABLE(resultado VARCHAR, mensaje TEXT) AS $$
DECLARE
    v_qr RECORD;
    v_funcion RECORD;
    v_ahora TIMESTAMP := CURRENT_TIMESTAMP;
BEGIN
    -- Si existe el QR
    SELECT * INTO v_qr FROM qr WHERE codigo = p_codigo;
    IF NOT FOUND THEN
        RETURN QUERY SELECT 'RECHAZADO'::VARCHAR, 'QR no encontrado'::TEXT;
        RETURN;
    END IF;

    -- Ya se uso
    IF v_qr.usado THEN
        INSERT INTO acceso_puerta_log (boleto_id, resultado, operador_id)
        VALUES (v_qr.boleto_id, 'RECHAZADO_DUPLICADO', p_operador_id);
        RETURN QUERY SELECT 'RECHAZADO'::VARCHAR, 'Entrada ya utilizada'::TEXT;
        RETURN;
    END IF;

    -- Verificar horario
    SELECT f.* INTO v_funcion
    FROM boleto b JOIN funcion f ON f.id = b.funcion_id
    WHERE b.id = v_qr.boleto_id;

    IF v_ahora < v_funcion.fecha_hora_inicio - INTERVAL '30 minutes'
       OR v_ahora > v_funcion.fecha_hora_inicio + INTERVAL '15 minutes' THEN
        INSERT INTO acceso_puerta_log (boleto_id, resultado, operador_id)
        VALUES (v_qr.boleto_id, 'RECHAZADO_HORARIO', p_operador_id);
        RETURN QUERY SELECT 'RECHAZADO'::VARCHAR, 'Fuera del horario de tolerancia'::TEXT;
        RETURN;
    END IF;

    -- Todo ok
    UPDATE qr SET usado = TRUE, fecha_uso = v_ahora WHERE id = v_qr.id;
    INSERT INTO acceso_puerta_log (boleto_id, resultado, operador_id)
    VALUES (v_qr.boleto_id, 'EXITOSO', p_operador_id);
    RETURN QUERY SELECT 'APROBADO'::VARCHAR, 'Acceso permitido'::TEXT;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fn_bloquear_asiento(
    p_funcion_id INT,
    p_asiento_id INT,
    p_usuario_id INT,
    p_precio NUMERIC,
    p_transaccion_id INT DEFAULT NULL
) RETURNS INT AS $$
DECLARE
    v_boleto_id INT;
BEGIN
    INSERT INTO boleto (
        funcion_id, asiento_id, usuario_id, transaccion_id,
        estado, precio_final, reservado_hasta
    ) VALUES (
        p_funcion_id, p_asiento_id, p_usuario_id, p_transaccion_id,
        'reservado', p_precio,
        CURRENT_TIMESTAMP + INTERVAL '2 minutes'
    )
    RETURNING id INTO v_boleto_id;
    RETURN v_boleto_id;
END;
$$ LANGUAGE plpgsql;


-- Roles y usuarios
INSERT INTO rol (nombre) VALUES ('cliente'), ('operador'), ('admin') ON CONFLICT DO NOTHING;

INSERT INTO usuario (nombre, email, password_hash) 
VALUES ('Cliente Demo', 'cliente@imax.com', '123') ON CONFLICT DO NOTHING;
INSERT INTO usuario (nombre, email, password_hash) 
VALUES ('Operador Puerta', 'operador@imax.com', '123') ON CONFLICT DO NOTHING;

INSERT INTO usuario_rol (usuario_id, rol_id) 
SELECT u.id, r.id FROM usuario u, rol r WHERE u.email='cliente@imax.com' AND r.nombre='cliente' ON CONFLICT DO NOTHING;
INSERT INTO usuario_rol (usuario_id, rol_id) 
SELECT u.id, r.id FROM usuario u, rol r WHERE u.email='operador@imax.com' AND r.nombre='operador' ON CONFLICT DO NOTHING;

-- metodos de pago
INSERT INTO metodo_pago (nombre, tipo) VALUES ('Tarjeta', 'tarjeta'), ('PayPal', 'wallet') ON CONFLICT DO NOTHING;

-- película, sala, asientos y función
DO $$
DECLARE
    v_sala_id INT; v_peli_id INT; v_fila TEXT; v_col INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sala WHERE nombre='Sala IMAX 1') THEN
        INSERT INTO sala (nombre, ubicacion, capacidad) VALUES ('Sala IMAX 1', 'Los Angeles', 30) RETURNING id INTO v_sala_id;
        FOR v_fila IN SELECT unnest(ARRAY['A','B','C']) LOOP
            FOR v_col IN 1..10 LOOP
                INSERT INTO asiento (sala_id, fila, columna, zona, tipo) VALUES (v_sala_id, v_fila, v_col, 'General', 'estandar');
            END LOOP;
        END LOOP;
    ELSE
        SELECT id INTO v_sala_id FROM sala WHERE nombre='Sala IMAX 1';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pelicula WHERE titulo='Dune 3') THEN
        INSERT INTO pelicula (titulo, sinopsis, clasificacion, duracion_min, genero, activa) 
        VALUES ('Dune 3', 'La saga continúa', 'PG-13', 160, 'Sci-Fi', TRUE) RETURNING id INTO v_peli_id;
    ELSE
        SELECT id INTO v_peli_id FROM pelicula WHERE titulo='Dune 3';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM funcion) THEN
        INSERT INTO funcion (pelicula_id, sala_id, fecha_hora_inicio, fecha_hora_fin, precio_base) 
        VALUES (v_peli_id, v_sala_id, NOW() + INTERVAL '10 minutes', NOW() + INTERVAL '3 hours', 15.00);
    END IF;
END $$;
