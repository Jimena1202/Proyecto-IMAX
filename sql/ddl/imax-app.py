import tkinter as tk
from tkinter import messagebox, ttk
from datetime import datetime
import customtkinter as ctk
import psycopg2
import qrcode
from PIL import Image

ctk.set_appearance_mode("System")
ctk.set_default_color_theme("blue")


class AppIMAX(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("IMAX - Sistema de Entradas")
        self.geometry("1400x820")
        self.minsize(1150, 700)

        self.conn_params = {
            "dbname": "IMAX",
            "user": "postgres",
            "password": "michiyyo",
            "host": "localhost",
            "port": "5432",
        }

        self.usuario_id = None
        self.operador_id = None
        self.funcion_seleccionada = None
        self.asientos_seleccionados = []
        self.transaccion_actual = None
        self.botones_asientos = {}
        self.funciones_combo = {}
        self.codigos_qr = {}

        self.grid_rowconfigure(0, weight=1)
        self.grid_columnconfigure(1, weight=1)

        self.configurar_estilos()
        self.crear_sidebar()
        self.crear_area_principal()
        self.cargar_usuarios_demo()
        self.actualizar_todo()

    # ---------- INFRAESTRUCTURA ----------
    def obtener_conexion(self):
        return psycopg2.connect(**self.conn_params)

    def ejecutar_consulta(self, sql, params=None, fetch=False):
        conn = None
        try:
            conn = self.obtener_conexion()
            with conn.cursor() as cur:
                cur.execute(sql, params)
                rows = cur.fetchall() if fetch else None
            conn.commit()
            return rows
        except Exception:
            if conn:
                conn.rollback()
            raise
        finally:
            if conn:
                conn.close()

    def configurar_estilos(self):
        style = ttk.Style()
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("Treeview", rowheight=30, font=("Arial", 10))
        style.configure("Treeview.Heading", font=("Arial", 10, "bold"))

    def crear_treeview(self, parent, columns, widths):
        contenedor = ctk.CTkFrame(parent, fg_color="transparent")
        contenedor.pack(fill="both", expand=True, padx=15, pady=(0, 15))
        tree = ttk.Treeview(contenedor, columns=columns, show="headings")
        for col, width in zip(columns, widths):
            tree.heading(col, text=col)
            tree.column(col, width=width, anchor="center")
        scroll_y = ttk.Scrollbar(contenedor, orient="vertical", command=tree.yview)
        scroll_x = ttk.Scrollbar(contenedor, orient="horizontal", command=tree.xview)
        tree.configure(yscrollcommand=scroll_y.set, xscrollcommand=scroll_x.set)
        tree.grid(row=0, column=0, sticky="nsew")
        scroll_y.grid(row=0, column=1, sticky="ns")
        scroll_x.grid(row=1, column=0, sticky="ew")
        contenedor.grid_rowconfigure(0, weight=1)
        contenedor.grid_columnconfigure(0, weight=1)
        return tree

    def crear_encabezado(self, parent, titulo, descripcion):
        ctk.CTkLabel(parent, text=titulo,
                     font=ctk.CTkFont(size=24, weight="bold")).pack(
            anchor="w", padx=15, pady=(15, 0))
        ctk.CTkLabel(parent, text=descripcion,
                     font=ctk.CTkFont(size=12)).pack(
            anchor="w", padx=15, pady=(0, 12))

    # ---------- SIDEBAR ----------
    def crear_sidebar(self):
        self.sidebar_frame = ctk.CTkFrame(self, width=235, corner_radius=0)
        self.sidebar_frame.grid(row=0, column=0, sticky="nsew")
        self.sidebar_frame.grid_propagate(False)
        self.sidebar_frame.grid_rowconfigure(10, weight=1)

        ctk.CTkLabel(self.sidebar_frame, text=" IMAX",
                     font=ctk.CTkFont(size=22, weight="bold")).grid(
            row=0, column=0, padx=20, pady=(28, 5), sticky="w")

        ctk.CTkLabel(self.sidebar_frame, text="Sistema de venta de entradas",
                     font=ctk.CTkFont(size=11), wraplength=190,
                     justify="left").grid(
            row=1, column=0, padx=20, pady=(0, 25), sticky="w")

        self.botones_nav = {}
        modulos = [
            ("Cartelera", "🎥"),
            ("Comprar", "🎟️"),
            ("Mis Boletos", "🎫"),
            ("Puerta", "🚪"),
            ("Admin", "📊"),
        ]
        for i, (nombre, icono) in enumerate(modulos, start=2):
            bt = ctk.CTkButton(
                self.sidebar_frame, text=f"{icono}  {nombre}", anchor="w",
                fg_color="transparent",
                command=lambda n=nombre: self.seleccionar_modulo(n))
            bt.grid(row=i, column=0, padx=15, pady=5, sticky="ew")
            self.botones_nav[nombre] = bt

        ctk.CTkLabel(self.sidebar_frame, text="APARIENCIA",
                     font=ctk.CTkFont(size=11, weight="bold")).grid(
            row=11, column=0, padx=20, pady=(10, 5), sticky="w")

        self.option_mode = ctk.CTkOptionMenu(
            self.sidebar_frame, values=["System", "Dark", "Light"],
            command=ctk.set_appearance_mode)
        self.option_mode.set("System")
        self.option_mode.grid(row=12, column=0, padx=15, pady=(0, 25), sticky="ew")

    # ---------- ÁREA PRINCIPAL ----------
    def crear_area_principal(self):
        self.main_container = ctk.CTkFrame(self, fg_color="transparent")
        self.main_container.grid(row=0, column=1, sticky="nsew", padx=20, pady=20)
        self.main_container.grid_rowconfigure(0, weight=1)
        self.main_container.grid_columnconfigure(0, weight=1)

        self.tabview = ctk.CTkTabview(self.main_container,
                                      command=self.al_cambiar_pestana)
        self.tabview.grid(row=0, column=0, sticky="nsew")

        self.tab_cartelera = self.tabview.add("Cartelera")
        self.tab_comprar = self.tabview.add("Comprar")
        self.tab_mis_boletos = self.tabview.add("Mis Boletos")
        self.tab_puerta = self.tabview.add("Puerta")
        self.tab_admin = self.tabview.add("Admin")

        self.configurar_cartelera()
        self.configurar_comprar()
        self.configurar_mis_boletos()
        self.configurar_puerta()
        self.configurar_admin()
        self.seleccionar_modulo("Cartelera")

    def seleccionar_modulo(self, nombre):
        self.tabview.set(nombre)
        for modulo, boton in self.botones_nav.items():
            boton.configure(fg_color=("gray75", "gray25")
                            if modulo == nombre else "transparent")

    def al_cambiar_pestana(self):
        nombre = self.tabview.get()
        if nombre in self.botones_nav:
            for modulo, boton in self.botones_nav.items():
                boton.configure(fg_color=("gray75", "gray25")
                                if modulo == nombre else "transparent")

    # ==================== CARTELERA ====================
    def configurar_cartelera(self):
        self.crear_encabezado(
            self.tab_cartelera, "Cartelera",
            "Explora las funciones activas disponibles en IMAX.")
        cuerpo = ctk.CTkFrame(self.tab_cartelera, fg_color="transparent")
        cuerpo.pack(fill="both", expand=True, padx=10, pady=5)

        top = ctk.CTkFrame(cuerpo, fg_color="transparent")
        top.pack(fill="x", padx=15, pady=(5, 10))
        ctk.CTkButton(top, text=" Actualizar",
                      command=self.cargar_datos_cartelera).pack(side="left")

        self.tree_cartelera = self.crear_treeview(
            cuerpo,
            ("ID", "Película", "Clasif.", "Género", "Sala", "Inicio", "Precio"),
            (60, 260, 90, 130, 180, 170, 90))

    def cargar_datos_cartelera(self):
        try:
            rows = self.ejecutar_consulta(
                """SELECT f.id, p.titulo, p.clasificacion, p.genero,
                          s.nombre, f.fecha_hora_inicio, f.precio_base
                   FROM funcion f
                   JOIN pelicula p ON p.id = f.pelicula_id
                   JOIN sala s ON s.id = f.sala_id
                   WHERE f.estado = 'activa' AND f.fecha_hora_inicio > NOW()
                   ORDER BY f.fecha_hora_inicio""", fetch=True)
            for item in self.tree_cartelera.get_children():
                self.tree_cartelera.delete(item)
            for r in rows:
                fecha = r[5].strftime("%Y-%m-%d %H:%M") if hasattr(r[5], "strftime") else r[5]
                self.tree_cartelera.insert("", "end",
                    values=(r[0], r[1], r[2], r[3], r[4], fecha, f"${r[6]}"))
        except Exception as e:
            print(f"Error cartelera: {e}")

    # ==================== COMPRAR ====================
    def configurar_comprar(self):
        self.crear_encabezado(
            self.tab_comprar, "Comprar Boletos",
            "Selecciona una función, elige tus asientos y completa el pago.")

        cuerpo = ctk.CTkFrame(self.tab_comprar, fg_color="transparent")
        cuerpo.pack(fill="both", expand=True, padx=10, pady=5)

        top = ctk.CTkFrame(cuerpo)
        top.pack(fill="x", padx=10, pady=(5, 10))
        ctk.CTkLabel(top, text="Función:").pack(side="left", padx=(15, 8), pady=12)
        self.combo_funcion = ctk.CTkComboBox(
            top, values=["Seleccione una función"], state="readonly",
            width=600, command=self.al_seleccionar_funcion)
        self.combo_funcion.set("Seleccione una función")
        self.combo_funcion.pack(side="left", padx=(0, 15), pady=12,
                                fill="x", expand=True)

        legend = ctk.CTkFrame(cuerpo, fg_color="transparent")
        legend.pack(fill="x", padx=20, pady=(0, 8))
        ctk.CTkLabel(legend,
                     text="🟢 Disponible   🔴 Ocupado   🟡 Bloqueado   🔵 Seleccionado",
                     font=ctk.CTkFont(size=12)).pack(anchor="w")

        split = ctk.CTkFrame(cuerpo, fg_color="transparent")
        split.pack(fill="both", expand=True, padx=10, pady=5)

        self.seats_scroll = ctk.CTkScrollableFrame(split,
                                                   label_text="Mapa de asientos")
        self.seats_scroll.pack(side="left", fill="both", expand=True, padx=(0, 10))

        self.seats_frame = ctk.CTkFrame(self.seats_scroll, fg_color="transparent")
        self.seats_frame.pack(fill="both", expand=True, padx=5, pady=5)

        panel = ctk.CTkFrame(split, width=340)
        panel.pack(side="right", fill="y", padx=(10, 0))
        panel.pack_propagate(False)

        ctk.CTkLabel(panel, text="Resumen de compra",
                     font=ctk.CTkFont(size=16, weight="bold")).pack(pady=(15, 10))
        self.lbl_seleccion = ctk.CTkLabel(panel, text="Asientos: 0",
                                          font=ctk.CTkFont(size=13))
        self.lbl_seleccion.pack(pady=5)
        self.lbl_total = ctk.CTkLabel(panel, text="Total: $0.00",
                                      font=ctk.CTkFont(size=18, weight="bold"))
        self.lbl_total.pack(pady=10)

        ctk.CTkButton(panel, text=" Reservar",
                      command=self.reservar_asientos).pack(
            fill="x", padx=20, pady=(15, 5))
        ctk.CTkButton(panel, text=" Pago aprobado",
                      command=self.pago_aprobado,
                      fg_color="#2d8f4e", hover_color="#1e6b38").pack(
            fill="x", padx=20, pady=5)
        ctk.CTkButton(panel, text=" Pago rechazado",
                      command=self.pago_rechazado,
                      fg_color="#b33939", hover_color="#8f2d2d").pack(
            fill="x", padx=20, pady=5)
        ctk.CTkButton(panel, text=" Limpiar",
                      command=self.limpiar_todo,
                      fg_color="gray").pack(fill="x", padx=20, pady=(5, 20))

        self.lbl_estado = ctk.CTkLabel(panel, text="", wraplength=300)
        self.lbl_estado.pack(pady=(10, 15))

    def cargar_funciones_combo(self):
        try:
            rows = self.ejecutar_consulta(
                """SELECT f.id, p.titulo, f.fecha_hora_inicio, s.nombre
                   FROM funcion f
                   JOIN pelicula p ON p.id = f.pelicula_id
                   JOIN sala s ON s.id = f.sala_id
                   WHERE f.estado='activa' AND f.fecha_hora_inicio > NOW()
                   ORDER BY f.fecha_hora_inicio""", fetch=True)
            self.funciones_combo = {}
            valores = ["Seleccione una función"]
            for r in rows:
                fecha = r[2].strftime("%Y-%m-%d %H:%M") if hasattr(r[2], "strftime") else r[2]
                etiqueta = f"{r[1]} — {fecha} — {r[3]} (#{r[0]})"
                self.funciones_combo[etiqueta] = r[0]
                valores.append(etiqueta)
            self.combo_funcion.configure(values=valores)
        except Exception as e:
            print(f"Error combo funciones: {e}")

    def al_seleccionar_funcion(self, _=None):
        etiqueta = self.combo_funcion.get()
        fid = self.funciones_combo.get(etiqueta)
        if fid is None:
            return
        self.funcion_seleccionada = fid
        self.limpiar_seleccion()
        self.dibujar_asientos(fid)

    def dibujar_asientos(self, funcion_id):
        for w in self.seats_frame.winfo_children():
            w.destroy()
        self.botones_asientos = {}

        try:
            sala = self.ejecutar_consulta(
                "SELECT sala_id FROM funcion WHERE id=%s",
                (funcion_id,), fetch=True)
            if not sala:
                return
            sala_id = sala[0][0]
            asientos = self.ejecutar_consulta(
                """SELECT a.id, a.fila, a.columna,
                    COALESCE(
                        (SELECT b.estado FROM boleto b
                         WHERE b.asiento_id=a.id AND b.funcion_id=%s
                           AND b.estado IN ('reservado','pagado') LIMIT 1),
                        'disponible'
                    )
                   FROM asiento a
                   WHERE a.sala_id=%s
                   ORDER BY a.fila, a.columna""",
                (funcion_id, sala_id), fetch=True)
        except Exception as e:
            print(f"Error asientos: {e}")
            return

        filas = {}
        for a in asientos:
            filas.setdefault(a[1], []).append((a[0], a[1], a[2], a[3]))

        for idx_fila, fila in enumerate(sorted(filas.keys())):
            ctk.CTkLabel(self.seats_frame, text=fila,
                         font=ctk.CTkFont(size=12, weight="bold")).grid(
                row=idx_fila, column=0, padx=(10, 15), pady=3)
            for idx_col, (aid, f, c, estado) in enumerate(filas[fila], start=1):
                color = self.color_por_estado(estado)
                btn = ctk.CTkButton(
                    self.seats_frame, text=str(c), width=38, height=38,
                    fg_color=color, hover_color=color,
                    state="disabled" if estado in ("pagado", "reservado") else "normal",
                    command=lambda i=aid: self.toggle_asiento(i))
                btn.grid(row=idx_fila, column=idx_col, padx=2, pady=2)
                self.botones_asientos[aid] = (btn, estado)

    def color_por_estado(self, estado):
        if estado == "disponible":
            return "#2d8f4e"
        elif estado == "pagado":
            return "#b33939"
        elif estado == "reservado":
            return "#c9a227"
        return "#555"

    def toggle_asiento(self, asiento_id):
        if asiento_id in self.asientos_seleccionados:
            self.asientos_seleccionados.remove(asiento_id)
            self.botones_asientos[asiento_id][0].configure(fg_color="#2d8f4e")
        else:
            self.asientos_seleccionados.append(asiento_id)
            self.botones_asientos[asiento_id][0].configure(fg_color="#3a6ea5")
        self.actualizar_resumen()

    def actualizar_resumen(self):
        n = len(self.asientos_seleccionados)
        pb = 0.0
        if self.funcion_seleccionada:
            r = self.ejecutar_consulta(
                "SELECT precio_base FROM funcion WHERE id=%s",
                (self.funcion_seleccionada,), fetch=True)
            if r:
                pb = float(r[0][0])
        self.lbl_seleccion.configure(text=f"Asientos: {n}")
        self.lbl_total.configure(text=f"Total: ${n*pb:.2f}")

    def limpiar_seleccion(self):
        self.asientos_seleccionados = []
        self.transaccion_actual = None
        if hasattr(self, "lbl_seleccion"):
            self.lbl_seleccion.configure(text="Asientos: 0")
            self.lbl_total.configure(text="Total: $0.00")
        if hasattr(self, "lbl_estado"):
            self.lbl_estado.configure(text="")

    def limpiar_todo(self):
        if self.transaccion_actual:
            try:
                self.ejecutar_consulta(
                    "SELECT fn_cancelar_compra(%s, %s)",
                    (self.transaccion_actual, "CANCELADO_USUARIO"))
            except Exception:
                pass
        self.limpiar_seleccion()
        if self.funcion_seleccionada:
            self.dibujar_asientos(self.funcion_seleccionada)

    def reservar_asientos(self):
        if not self.asientos_seleccionados:
            messagebox.showwarning("Sin asientos", "Selecciona al menos un asiento.")
            return
        if not self.usuario_id:
            messagebox.showerror("Sin usuario", "No hay usuario demo cargado.")
            return
        if self.transaccion_actual:
            messagebox.showinfo("Ya reservado", "Ya tienes una reserva activa.")
            return
        try:
            r = self.ejecutar_consulta(
                "SELECT precio_base FROM funcion WHERE id=%s",
                (self.funcion_seleccionada,), fetch=True)
            pb = float(r[0][0])
            total = pb * len(self.asientos_seleccionados)

            r = self.ejecutar_consulta(
                "INSERT INTO transaccion (usuario_id, monto_total) VALUES (%s,%s) RETURNING id",
                (self.usuario_id, total), fetch=True)
            tid = r[0][0]

            for aid in self.asientos_seleccionados:
                self.ejecutar_consulta(
                    "SELECT fn_bloquear_asiento(%s,%s,%s,%s,%s)",
                    (self.funcion_seleccionada, aid, self.usuario_id, pb, tid))

            self.transaccion_actual = tid
            self.lbl_estado.configure(
                text=f" Reserva creada (#{tid}). Tienes 2 min para pagar.",
                text_color="#2d8f4e")
            self.dibujar_asientos(self.funcion_seleccionada)
        except Exception as e:
            self.lbl_estado.configure(text=f"❌ {e}", text_color="#b33939")
            messagebox.showerror("Error al reservar", str(e))

    def pago_aprobado(self):
        if not self.transaccion_actual:
            messagebox.showwarning("Sin reserva", "Primero reserva asientos.")
            return
        try:
            self.ejecutar_consulta(
                "SELECT fn_confirmar_compra(%s)", (self.transaccion_actual,))
            messagebox.showinfo("Pago aprobado",
                                "QR generado. Revisa 'Mis Boletos'.")
            self.lbl_estado.configure(text=" Pago aprobado.",
                                      text_color="#2d8f4e")
            self.transaccion_actual = None
            self.asientos_seleccionados = []
            if self.funcion_seleccionada:
                self.dibujar_asientos(self.funcion_seleccionada)
            self.cargar_datos_mis_boletos()
            self.cargar_historial_accesos()
            self.cargar_metricas()
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def pago_rechazado(self):
        if not self.transaccion_actual:
            messagebox.showwarning("Sin reserva", "Primero reserva asientos.")
            return
        try:
            self.ejecutar_consulta(
                "SELECT fn_cancelar_compra(%s)", (self.transaccion_actual,))
            messagebox.showinfo("Pago rechazado", "Asientos liberados.")
            self.lbl_estado.configure(text=" Pago rechazado. Asientos liberados.",
                                      text_color="#b33939")
            self.transaccion_actual = None
            self.asientos_seleccionados = []
            if self.funcion_seleccionada:
                self.dibujar_asientos(self.funcion_seleccionada)
        except Exception as e:
            messagebox.showerror("Error", str(e))

    # ==================== MIS BOLETOS ====================
    def configurar_mis_boletos(self):
        self.crear_encabezado(
            self.tab_mis_boletos, "Mis Boletos",
            "Consulta tus boletos y descarga el código QR.")
        cuerpo = ctk.CTkFrame(self.tab_mis_boletos, fg_color="transparent")
        cuerpo.pack(fill="both", expand=True, padx=10, pady=5)

        top = ctk.CTkFrame(cuerpo, fg_color="transparent")
        top.pack(fill="x", padx=15, pady=(5, 10))
        ctk.CTkButton(top, text=" Actualizar",
                      command=self.cargar_datos_mis_boletos).pack(side="left")

        split = ctk.CTkFrame(cuerpo, fg_color="transparent")
        split.pack(fill="both", expand=True, padx=10, pady=5)

        left = ctk.CTkFrame(split)
        left.pack(side="left", fill="both", expand=True, padx=(0, 10))
        self.tree_boletos = self.crear_treeview(
            left,
            ("ID", "Película", "Sala", "Asiento", "Función", "Estado", "Código QR"),
            (50, 190, 130, 90, 170, 100, 260))
        self.tree_boletos.bind("<<TreeviewSelect>>", self.mostrar_qr)

        right = ctk.CTkFrame(split, width=300)
        right.pack(side="right", fill="y", padx=(10, 0))
        right.pack_propagate(False)
        ctk.CTkLabel(right, text="Código QR",
                     font=ctk.CTkFont(size=16, weight="bold")).pack(pady=(15, 10))
        self.qr_label = ctk.CTkLabel(right, text="Selecciona un boleto")
        self.qr_label.pack(pady=10)
        self.qr_codigo_label = ctk.CTkLabel(right, text="",
                                            font=ctk.CTkFont(size=11),
                                            wraplength=280)
        self.qr_codigo_label.pack(pady=(0, 15))

    def cargar_datos_mis_boletos(self):
        if not self.usuario_id:
            return
        try:
            rows = self.ejecutar_consulta(
                """SELECT b.id, p.titulo, s.nombre, a.fila||'-'||a.columna,
                          f.fecha_hora_inicio, b.estado, q.codigo
                   FROM boleto b
                   JOIN funcion f ON f.id=b.funcion_id
                   JOIN pelicula p ON p.id=f.pelicula_id
                   JOIN sala s ON s.id=f.sala_id
                   JOIN asiento a ON a.id=b.asiento_id
                   LEFT JOIN qr q ON q.boleto_id=b.id
                   WHERE b.usuario_id=%s AND b.estado IN ('reservado','pagado')
                   ORDER BY f.fecha_hora_inicio DESC""",
                (self.usuario_id,), fetch=True)
            for item in self.tree_boletos.get_children():
                self.tree_boletos.delete(item)
            self.codigos_qr = {}
            for r in rows:
                fecha = r[4].strftime("%Y-%m-%d %H:%M") if hasattr(r[4], "strftime") else r[4]
                codigo = r[6] or "—"
                self.codigos_qr[r[0]] = codigo
                self.tree_boletos.insert("", "end",
                    values=(r[0], r[1], r[2], r[3], fecha, r[5], codigo))
        except Exception as e:
            print(f"Error boletos: {e}")

    def mostrar_qr(self, _=None):
        sel = self.tree_boletos.selection()
        if not sel:
            return
        bid = self.tree_boletos.item(sel[0])["values"][0]
        codigo = self.codigos_qr.get(bid)
        if not codigo or codigo == "—":
            self.qr_label.configure(image=None, text="Boleto sin QR aún")
            self.qr_codigo_label.configure(text="")
            return
        try:
            qr_obj = qrcode.QRCode(box_size=8, border=2)
            qr_obj.add_data(codigo)
            qr_obj.make()
            img = qr_obj.make_image(fill_color="black",
                                    back_color="white").convert("RGB")
            img = img.resize((250, 250), Image.Resampling.LANCZOS)
            ctk_img = ctk.CTkImage(light_image=img, dark_image=img,
                                   size=(250, 250))
            self.qr_label.configure(image=ctk_img, text="")
            self.qr_codigo_label.configure(text=codigo)
        except Exception as e:
            self.qr_label.configure(text=f"Error QR: {e}")

    # ==================== PUERTA ====================
    def configurar_puerta(self):
        self.crear_encabezado(
            self.tab_puerta, "Puerta / Check-in",
            "Valida el código QR del boleto en la entrada.")
        cuerpo = ctk.CTkFrame(self.tab_puerta, fg_color="transparent")
        cuerpo.pack(fill="both", expand=True, padx=10, pady=5)

        top = ctk.CTkFrame(cuerpo)
        top.pack(fill="x", padx=10, pady=(5, 10))
        ctk.CTkLabel(top, text="Código QR:").pack(side="left",
                                                  padx=(15, 8), pady=12)
        self.entry_qr = ctk.CTkEntry(top, placeholder_text="Pega el código aquí")
        self.entry_qr.pack(side="left", padx=(0, 10), pady=12,
                           fill="x", expand=True)
        ctk.CTkButton(top, text="Validar",
                      command=self.validar_qr).pack(side="left",
                                                    padx=(0, 15), pady=12)

        self.lbl_resultado = ctk.CTkLabel(
            cuerpo, text="", font=ctk.CTkFont(size=16, weight="bold"))
        self.lbl_resultado.pack(pady=(5, 15))

        ctk.CTkLabel(cuerpo, text="Historial de accesos",
                     font=ctk.CTkFont(size=14, weight="bold")).pack(
            anchor="w", padx=15, pady=(10, 5))

        self.tree_accesos = self.crear_treeview(
            cuerpo, ("Fecha", "Boleto", "Resultado", "Operador"),
            (200, 100, 260, 180))

    def validar_qr(self):
        codigo = self.entry_qr.get().strip()
        if not codigo:
            return
        if not self.operador_id:
            messagebox.showerror("Sin operador", "No hay operador cargado.")
            return
        try:
            r = self.ejecutar_consulta(
                "SELECT * FROM fn_check_in_qr(%s, %s)",
                (codigo, self.operador_id), fetch=True)
            resultado, mensaje = r[0][0], r[0][1]
            if resultado == "APROBADO":
                self.lbl_resultado.configure(text=f" {mensaje}",
                                             text_color="#2d8f4e")
            else:
                self.lbl_resultado.configure(text=f" {mensaje}",
                                             text_color="#b33939")
            self.cargar_historial_accesos()
        except Exception as e:
            self.lbl_resultado.configure(text=f" {e}",
                                         text_color="#b33939")

    def cargar_historial_accesos(self):
        try:
            rows = self.ejecutar_consulta(
                """SELECT l.fecha, l.boleto_id, l.resultado,
                          COALESCE(u.email,'—')
                   FROM acceso_puerta_log l
                   LEFT JOIN usuario u ON u.id=l.operador_id
                   ORDER BY l.fecha DESC LIMIT 20""", fetch=True)
            for item in self.tree_accesos.get_children():
                self.tree_accesos.delete(item)
            for r in rows:
                fecha = r[0].strftime("%Y-%m-%d %H:%M:%S") if hasattr(r[0], "strftime") else r[0]
                self.tree_accesos.insert("", "end",
                    values=(fecha, r[1], r[2], r[3]))
        except Exception as e:
            print(f"Error historial: {e}")

    # ==================== ADMIN ====================
    def configurar_admin(self):
        self.crear_encabezado(
            self.tab_admin, "Panel Administrador",
            "Métricas en tiempo real, transacciones y auditoría.")
        cuerpo = ctk.CTkFrame(self.tab_admin, fg_color="transparent")
        cuerpo.pack(fill="both", expand=True, padx=10, pady=5)

        metricas = ctk.CTkFrame(cuerpo)
        metricas.pack(fill="x", padx=10, pady=(5, 10))
        self.lbl_metricas = ctk.CTkLabel(
            metricas, text="Cargando métricas...",
            font=ctk.CTkFont(size=13), justify="left")
        self.lbl_metricas.pack(padx=20, pady=15, anchor="w")

        ctk.CTkButton(cuerpo, text=" Actualizar métricas",
                      command=self.cargar_metricas).pack(
            anchor="w", padx=15, pady=(0, 10))

        ctk.CTkLabel(cuerpo, text="Auditoría de asientos (últimos 20 eventos)",
                     font=ctk.CTkFont(size=14, weight="bold")).pack(
            anchor="w", padx=15, pady=(10, 5))

        self.tree_auditoria = self.crear_treeview(
            cuerpo,
            ("ID", "Acción", "Asiento", "Función", "Usuario", "Fecha"),
            (70, 130, 90, 90, 90, 200))

    def cargar_metricas(self):
        try:
            v = self.ejecutar_consulta(
                """SELECT COUNT(*), COALESCE(SUM(monto_total),0)
                   FROM transaccion WHERE estado='aprobada'""", fetch=True)
            n_tx, total = v[0][0], float(v[0][1])

            b = self.ejecutar_consulta(
                "SELECT COUNT(*) FROM boleto WHERE estado='pagado'",
                fetch=True)
            n_boletos = b[0][0]

            ocup = self.ejecutar_consulta(
                """SELECT p.titulo, f.id,
                          COUNT(b.id) FILTER (WHERE b.estado='pagado'),
                          s.capacidad
                   FROM funcion f
                   JOIN pelicula p ON p.id=f.pelicula_id
                   JOIN sala s ON s.id=f.sala_id
                   LEFT JOIN boleto b ON b.funcion_id=f.id
                   GROUP BY p.titulo, f.id, s.capacidad""", fetch=True)

            texto = (f" Transacciones aprobadas: {n_tx}   |   "
                     f"Ingresos totales: ${total:.2f}\n")
            texto += f" Boletos pagados: {n_boletos}\n\n"
            texto += " Ocupación por función:\n"
            for r in ocup:
                cap = r[3] if r[3] else 1
                pct = (r[2] / cap) * 100 if cap else 0
                texto += f"  • {r[0]} (función #{r[1]}): {pct:.1f}% ({r[2]}/{cap})\n"
            self.lbl_metricas.configure(text=texto)

            logs = self.ejecutar_consulta(
                """SELECT id, accion, asiento_id, funcion_id, usuario_id, fecha
                   FROM asiento_auditoria_log
                   ORDER BY fecha DESC LIMIT 20""", fetch=True)
            for item in self.tree_auditoria.get_children():
                self.tree_auditoria.delete(item)
            for r in logs:
                fecha = r[5].strftime("%Y-%m-%d %H:%M:%S") if hasattr(r[5], "strftime") else r[5]
                self.tree_auditoria.insert("", "end",
                    values=(r[0], r[1], r[2], r[3], r[4], fecha))
        except Exception as e:
            self.lbl_metricas.configure(text=f"Error: {e}")

    # ==================== INICIALIZACIÓN ====================
    def cargar_usuarios_demo(self):
        try:
            r = self.ejecutar_consulta(
                "SELECT id FROM usuario WHERE email='cliente@imax.com'",
                fetch=True)
            self.usuario_id = r[0][0] if r else None

            r = self.ejecutar_consulta(
                "SELECT id FROM usuario WHERE email='operador@imax.com'",
                fetch=True)
            self.operador_id = r[0][0] if r else None
        except Exception as e:
            print(f"Error usuarios demo: {e}")

    def actualizar_todo(self):
        self.cargar_datos_cartelera()
        self.cargar_funciones_combo()
        self.cargar_datos_mis_boletos()
        self.cargar_historial_accesos()
        self.cargar_metricas()


if __name__ == "__main__":
    app = AppIMAX()
    app.mainloop()