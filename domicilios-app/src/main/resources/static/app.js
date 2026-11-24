'use strict';
/*
 * Interfaz gráfica del sistema de domicilios.
 * Cada acción llama a la API REST de Spring Boot (fetch), y la API ejecuta el
 * INSERT / UPDATE / DELETE correspondiente en MySQL. Después de cada cambio la
 * tabla se vuelve a consultar, así que lo que se ve es siempre lo que hay en la base de datos.
 */

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------
const $ = (selector) => document.querySelector(selector);

/** Llama a la API. Si responde con error, lanza el mensaje que envía el backend. */
async function api(metodo, url, datos) {
    const opciones = { method: metodo, headers: {} };
    if (datos !== undefined) {
        opciones.headers['Content-Type'] = 'application/json';
        opciones.body = JSON.stringify(datos);
    }
    let respuesta;
    try {
        respuesta = await fetch(url, opciones);
    } catch {
        throw new Error('No hay conexión con el servidor. ¿Está corriendo la aplicación Spring Boot?');
    }
    const texto = await respuesta.text();
    let json = null;
    try { json = texto ? JSON.parse(texto) : null; } catch { /* respuesta sin JSON */ }
    if (!respuesta.ok) {
        throw new Error(json && json.error ? json.error : `Error ${respuesta.status}`);
    }
    return json;
}

const pesos = new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 });

let temporizadorAviso;
function aviso(mensaje, esError = false) {
    const caja = $('#aviso');
    caja.textContent = mensaje;
    caja.classList.toggle('es-error', esError);
    caja.hidden = false;
    clearTimeout(temporizadorAviso);
    temporizadorAviso = setTimeout(() => { caja.hidden = true; }, esError ? 6000 : 3000);
}

// ---------------------------------------------------------------------------
// Opciones para las listas desplegables
// ---------------------------------------------------------------------------
let catalogosCache = null;
async function catalogos() {
    if (!catalogosCache) catalogosCache = await api('GET', '/api/catalogos');
    return catalogosCache;
}
const desdeCatalogo = (clave) => async () => (await catalogos())[clave];

const opcionesClientes = async () =>
    (await api('GET', '/api/clientes')).map(c => ({
        id: c.numeroIdentificacion,
        nombre: `${c.nombre} ${c.apellido_Paterno} (${c.numeroIdentificacion})`
    }));

// Solo las direcciones del cliente elegido (regla del enunciado)
const opcionesDireccionesDelCliente = async (valores) => {
    if (!valores.idCliente) return [];
    const lista = await api('GET', `/api/direcciones?cliente=${encodeURIComponent(valores.idCliente)}`);
    return lista.map(d => ({ id: d.idDireccion, nombre: `${d.ubicacion} — ${d.nombreBarrio}` }));
};

const opcionesEstablecimientos = async () =>
    (await api('GET', '/api/establecimientos')).map(e => ({
        id: e.idEstablecimiento, nombre: `${e.nombreComercial} (${e.nombreTipoEstablecimiento})`
    }));

// Disponibles: activos y con menos de 2 solicitudes activas (regla de trg_validar_domiciliario)
const opcionesDomiciliariosDisponibles = async () =>
    (await api('GET', '/api/domiciliarios'))
        .filter(d => d.nombreEstadoDomiciliario === 'Activo' && Number(d.solicitudesActivas) < 2)
        .map(d => ({
            id: d.numeroIdentificacion,
            nombre: `${d.codigoUnico} · ${d.nombre} ${d.apellido_Paterno} (${d.nombreMedioTransporte}) · ${d.solicitudesActivas} activa(s)`
        }));

const opcionesTodosDomiciliarios = async () =>
    (await api('GET', '/api/domiciliarios')).map(d => ({
        id: d.numeroIdentificacion,
        nombre: `${d.codigoUnico} · ${d.nombre} ${d.apellido_Paterno}`
    }));

// Solo solicitudes con domiciliario: sin domiciliario no se registran incidentes (trg_validar_incidente)
const opcionesSolicitudes = async () =>
    (await api('GET', '/api/solicitudes'))
        .filter(s => s.idDomiciliario !== null && s.idDomiciliario !== undefined)
        .map(s => ({ id: s.numeroSolicitud, nombre: `${s.numeroSolicitud} · ${s.descripcion}` }));

// Campos comunes de Usuario (cliente y domiciliario)
const camposUsuario = [
    { name: 'numeroIdentificacion', label: 'Número de identificación', tipo: 'number', requerido: true, soloCrear: true },
    { name: 'nombre', label: 'Nombre', requerido: true },
    { name: 'apellido_Paterno', label: 'Apellido paterno', requerido: true },
    { name: 'apellido_Materno', label: 'Apellido materno', requerido: true },
    { name: 'numeroTelefono', label: 'Teléfono', requerido: true },
    { name: 'correoElectronico', label: 'Correo electrónico', tipo: 'email' }
];

// ---------------------------------------------------------------------------
// Configuración de cada pestaña: columnas de la tabla y campos del formulario
// ---------------------------------------------------------------------------
const ENTIDADES = {
    solicitudes: {
        titulo: 'Solicitudes', singular: 'solicitud', femenino: true, url: '/api/solicitudes', id: 'numeroSolicitud',
        columnas: [
            ['numeroSolicitud', 'N°'],
            ['fechaCreacion', 'Fecha'],
            ['horaCreacion', 'Hora'],
            ['nombreCliente', 'Cliente'],
            ['descripcion', 'Descripción'],
            ['lugarRecogida', 'Recogida'],
            ['direccionEntrega', 'Entrega'],
            ['montoTotal', 'Monto', v => pesos.format(v)],
            ['nombreMetodo', 'Pago'],
            ['nombreDomiciliario', 'Domiciliario'],
            ['nombreEstadoSolicitud', 'Estado', 'estado'],
            ['cantidadIncidentes', 'Incid.']
        ],
        campos: [
            { name: 'idCliente', label: 'Cliente', tipo: 'select', requerido: true, opciones: opcionesClientes },
            { name: 'idDireccion', label: 'Dirección de entrega', tipo: 'select', requerido: true,
              dependeDe: 'idCliente', opciones: opcionesDireccionesDelCliente,
              ayuda: 'Solo aparecen las direcciones registradas por el cliente elegido.' },
            { name: 'idEstablecimiento', label: 'Recoger en establecimiento aliado', tipo: 'select',
              vacio: '— Ninguno (usar dirección externa) —', opciones: opcionesEstablecimientos },
            { name: 'direccionRecogidaExterna', label: 'o recoger en dirección externa',
              ayuda: 'Llene solo uno de los dos: establecimiento o dirección externa.' },
            { name: 'descripcion', label: 'Descripción', tipo: 'textarea', requerido: true },
            { name: 'montoTotal', label: 'Monto total (COP)', tipo: 'number', requerido: true, step: '0.01', min: 0,
              ayuda: 'Debe ser mayor que 0.' },
            { name: 'idMetodoPago', label: 'Método de pago', tipo: 'select', requerido: true, opciones: desdeCatalogo('metodosPago') }
        ],
        acciones: [
            { texto: 'Asignar', fn: asignarDomiciliario },
            { texto: 'Estado', fn: cambiarEstado },
            { texto: 'Incidentes', fn: verIncidentes },
            { texto: 'Historial', fn: verHistorial }
        ]
    },

    clientes: {
        titulo: 'Clientes', singular: 'cliente', url: '/api/clientes', id: 'numeroIdentificacion',
        columnas: [
            ['numeroIdentificacion', 'Identificación'],
            ['nombre', 'Nombre'],
            ['apellido_Paterno', 'Apellido paterno'],
            ['apellido_Materno', 'Apellido materno'],
            ['numeroTelefono', 'Teléfono'],
            ['correoElectronico', 'Correo']
        ],
        campos: camposUsuario
    },

    direcciones: {
        titulo: 'Direcciones de entrega', singular: 'dirección', femenino: true, url: '/api/direcciones', id: 'idDireccion',
        columnas: [
            ['idDireccion', 'Código'],
            ['nombreCliente', 'Cliente'],
            ['ubicacion', 'Ubicación'],
            ['referencia', 'Referencia'],
            ['nombreBarrio', 'Barrio'],
            ['nombreComuna', 'Comuna']
        ],
        campos: [
            { name: 'idCliente', label: 'Cliente', tipo: 'select', requerido: true, opciones: opcionesClientes },
            { name: 'ubicacion', label: 'Ubicación', requerido: true },
            { name: 'referencia', label: 'Referencia', tipo: 'textarea' },
            { name: 'idBarrio', label: 'Barrio', tipo: 'select', requerido: true, opciones: desdeCatalogo('barrios') }
        ]
    },

    domiciliarios: {
        titulo: 'Domiciliarios', singular: 'domiciliario', url: '/api/domiciliarios', id: 'numeroIdentificacion',
        columnas: [
            ['codigoUnico', 'Código'],
            ['numeroIdentificacion', 'Identificación'],
            ['nombre', 'Nombre'],
            ['apellido_Paterno', 'Apellido'],
            ['numeroTelefono', 'Teléfono'],
            ['correoElectronico', 'Correo'],
            ['nombreMedioTransporte', 'Transporte'],
            ['nombreEstadoDomiciliario', 'Estado', 'estado'],
            ['solicitudesActivas', 'Activas']
        ],
        campos: [
            ...camposUsuario,
            { name: 'codigoUnico', label: 'Código único', tipo: 'number',
              ayuda: 'Déjelo vacío para generarlo automáticamente.' },
            { name: 'idMedioTransporte', label: 'Medio de transporte', tipo: 'select', requerido: true, opciones: desdeCatalogo('mediosTransporte') },
            { name: 'idEstadoDomiciliario', label: 'Estado', tipo: 'select', requerido: true, opciones: desdeCatalogo('estadosDomiciliario') }
        ]
    },

    establecimientos: {
        titulo: 'Establecimientos aliados', singular: 'establecimiento', url: '/api/establecimientos', id: 'idEstablecimiento',
        columnas: [
            ['idEstablecimiento', 'Código'],
            ['nombreComercial', 'Nombre comercial'],
            ['nombreTipoEstablecimiento', 'Tipo'],
            ['ubicacion', 'Ubicación'],
            ['nombreBarrio', 'Barrio'],
            ['nombreComuna', 'Comuna'],
            ['telefono', 'Teléfono'],
            ['email', 'Correo']
        ],
        campos: [
            { name: 'nombreComercial', label: 'Nombre comercial', requerido: true },
            { name: 'idTipoEstablecimiento', label: 'Tipo', tipo: 'select', requerido: true, opciones: desdeCatalogo('tiposEstablecimiento') },
            { name: 'ubicacion', label: 'Ubicación', requerido: true },
            { name: 'idBarrio', label: 'Barrio', tipo: 'select', requerido: true, opciones: desdeCatalogo('barrios') },
            { name: 'telefono', label: 'Teléfono', requerido: true },
            { name: 'email', label: 'Correo electrónico', tipo: 'email' }
        ]
    },

    reportes: {
        titulo: 'Reportes', soloLectura: true, columnas: []
    },

    incidentes: {
        titulo: 'Incidentes', singular: 'incidente', url: '/api/incidentes', id: 'codigoIncidente',
        columnas: [
            ['codigoIncidente', 'Código'],
            ['numeroSolicitud', 'Solicitud'],
            ['nombreTipoIncidente', 'Tipo'],
            ['descripcion', 'Descripción'],
            ['fechaIncidente', 'Fecha'],
            ['horaIncidente', 'Hora']
        ],
        campos: [
            { name: 'numeroSolicitud', label: 'Solicitud', tipo: 'select', requerido: true, opciones: opcionesSolicitudes,
              ayuda: 'Solo aparecen solicitudes que ya tienen domiciliario asignado.' },
            { name: 'idTipoIncidente', label: 'Tipo de incidente', tipo: 'select', requerido: true, opciones: desdeCatalogo('tiposIncidente') },
            { name: 'descripcion', label: 'Descripción', tipo: 'textarea', requerido: true },
            { name: 'fechaIncidente', label: 'Fecha', tipo: 'date', ayuda: 'Vacío = fecha de hoy.' },
            { name: 'horaIncidente', label: 'Hora', tipo: 'time', ayuda: 'Vacío = hora actual.' }
        ]
    }
};

// ---------------------------------------------------------------------------
// Reportes: usan los procedimientos, el cursor y las vistas de MySQL (Entregas 3 y 4)
// ---------------------------------------------------------------------------
const REPORTES = [
    { id: 'detalle', nombre: 'Detalle de solicitudes · vista vw_solicitudes_detalle',
      url: () => '/api/reportes/solicitudes-detalle' },
    { id: 'fecha', nombre: 'Solicitudes de una fecha · sp_solicitudes_por_fecha',
      params: [{ name: 'fecha', label: 'Fecha', tipo: 'date', valor: '2026-10-04' }],
      url: p => `/api/reportes/solicitudes-por-fecha?fecha=${encodeURIComponent(p.fecha)}` },
    { id: 'resumen', nombre: 'Resumen de un domiciliario · sp_resumen_domiciliario',
      params: [{ name: 'domiciliario', label: 'Domiciliario', tipo: 'select', opciones: opcionesTodosDomiciliarios }],
      url: p => `/api/reportes/resumen-domiciliario/${encodeURIComponent(p.domiciliario)}` },
    { id: 'desempeno', nombre: 'Desempeño de domiciliarios · cursor sp_reporte_desempeno_domiciliarios',
      url: () => '/api/reportes/desempeno-domiciliarios' },
    { id: 'disponibles', nombre: 'Domiciliarios disponibles · vista vw_domiciliarios_disponibles',
      url: () => '/api/reportes/domiciliarios-disponibles' },
    { id: 'clientes', nombre: 'Resumen por cliente · vista vw_resumen_clientes',
      url: () => '/api/reportes/clientes' },
    { id: 'establecimientos', nombre: 'Reporte por establecimiento · sp_reporte_establecimientos',
      params: [{ name: 'inicio', label: 'Desde', tipo: 'date', valor: '2026-09-01' },
               { name: 'fin', label: 'Hasta', tipo: 'date', valor: '2026-12-31' }],
      url: p => `/api/reportes/establecimientos?inicio=${encodeURIComponent(p.inicio)}&fin=${encodeURIComponent(p.fin)}` },
    { id: 'auditoria', nombre: 'Auditoría de solicitudes · tabla AuditoriaSolicitud',
      url: () => '/api/reportes/auditoria' }
];

/** Convierte nombres de columnas como "total_movilizado" o "fechaCambio" en "Total movilizado", "Fecha cambio". */
function tituloColumna(clave) {
    const texto = clave.replace(/_/g, ' ').replace(/([a-z])([A-Z])/g, '$1 $2').toLowerCase();
    return texto.charAt(0).toUpperCase() + texto.slice(1);
}

function columnasDesde(filasReporte) {
    if (!filasReporte.length) return [];
    return Object.keys(filasReporte[0]).map(k => {
        const esDinero = /monto|movilizado|pagado/i.test(k);
        return [k, tituloColumna(k), esDinero ? (v => pesos.format(v)) : undefined];
    });
}

async function prepararReportes() {
    const select = $('#tipoReporte');
    if (!select.options.length) {
        for (const r of REPORTES) select.append(new Option(r.nombre, r.id));
        select.addEventListener('change', pintarParametros);
    }
    await pintarParametros();
}

async function pintarParametros() {
    const reporte = REPORTES.find(r => r.id === $('#tipoReporte').value);
    const caja = $('#parametrosReporte');
    caja.replaceChildren();
    for (const p of reporte.params || []) {
        const label = document.createElement('label');
        label.className = 'parametro';
        label.append(Object.assign(document.createElement('span'), { textContent: p.label }));
        let input;
        if (p.tipo === 'select') {
            input = document.createElement('select');
            try {
                for (const o of await p.opciones()) input.append(new Option(o.nombre, o.id));
            } catch (e) { aviso(e.message, true); }
        } else {
            input = Object.assign(document.createElement('input'), { type: p.tipo, value: p.valor || '' });
        }
        input.name = p.name;
        label.append(input);
        caja.append(label);
    }
}

async function consultarReporte() {
    const reporte = REPORTES.find(r => r.id === $('#tipoReporte').value);
    const valores = {};
    for (const p of reporte.params || []) valores[p.name] = $('#parametrosReporte').querySelector(`[name="${p.name}"]`).value;
    try {
        filas = await api('GET', reporte.url(valores));
    } catch (e) {
        filas = [];
        aviso(e.message, true);
    }
    ENTIDADES.reportes.columnas = columnasDesde(filas);
    pintarTabla();
}

/** Muestra una tabla de solo lectura dentro de la ventana emergente (por ejemplo, el historial). */
function mostrarTablaEnDialogo(titulo, filasTabla) {
    $('#tituloDialogo').textContent = titulo;
    $('#errorDialogo').hidden = true;
    $('#guardar').hidden = true;
    $('#cancelar').textContent = 'Cerrar';
    const contenedor = $('#campos');
    contenedor.replaceChildren();
    if (!filasTabla.length) {
        contenedor.append(Object.assign(document.createElement('p'), { textContent: 'No hay registros.', className: 'tenue' }));
    } else {
        const tabla = document.createElement('table');
        tabla.className = 'tabla-dialogo';
        const columnas = Object.keys(filasTabla[0]);
        const trEnc = document.createElement('tr');
        for (const c of columnas) trEnc.append(Object.assign(document.createElement('th'), { textContent: tituloColumna(c) }));
        tabla.append(trEnc);
        for (const f of filasTabla) {
            const tr = document.createElement('tr');
            for (const c of columnas) tr.append(Object.assign(document.createElement('td'), { textContent: f[c] ?? '—' }));
            tabla.append(tr);
        }
        contenedor.append(tabla);
    }
    $('#formulario').onchange = null;
    $('#formulario').onsubmit = (ev) => { ev.preventDefault(); $('#dialogo').close(); };
    $('#dialogo').showModal();
}

// ---------------------------------------------------------------------------
// Tabla
// ---------------------------------------------------------------------------
let entidadActual = 'solicitudes';
let filas = [];

async function mostrar(clave) {
    entidadActual = clave;
    const ent = ENTIDADES[clave];
    document.querySelectorAll('#pestanas button').forEach(b =>
        b.classList.toggle('activa', b.dataset.entidad === clave));
    $('#titulo').textContent = ent.titulo;
    $('#panelReportes').hidden = !ent.soloLectura;
    $('#nuevo').hidden = !!ent.soloLectura;
    if (ent.soloLectura) {
        await prepararReportes();
        await consultarReporte();
        return;
    }
    try {
        filas = await api('GET', ent.url);
    } catch (e) {
        filas = [];
        aviso(e.message, true);
    }
    pintarTabla();
}

function pintarTabla() {
    const ent = ENTIDADES[entidadActual];
    const filtro = $('#buscar').value.trim().toLowerCase();
    const visibles = filtro
        ? filas.filter(f => ent.columnas.some(([c]) => String(f[c] ?? '').toLowerCase().includes(filtro)))
        : filas;

    // Encabezados
    const thead = $('#tabla thead');
    thead.replaceChildren();
    const trEnc = document.createElement('tr');
    for (const [, titulo] of ent.columnas) {
        const th = document.createElement('th');
        th.textContent = titulo;
        trEnc.append(th);
    }
    if (!ent.soloLectura) trEnc.append(Object.assign(document.createElement('th'), { textContent: 'Acciones' }));
    thead.append(trEnc);

    // Filas
    const tbody = $('#tabla tbody');
    tbody.replaceChildren();
    for (const fila of visibles) {
        const tr = document.createElement('tr');
        for (const [campo, , formato] of ent.columnas) {
            const td = document.createElement('td');
            const valor = fila[campo];
            if (valor === null || valor === undefined || valor === '') {
                td.textContent = '—';
                td.className = 'vacio';
            } else if (formato === 'estado') {
                const etiqueta = document.createElement('span');
                etiqueta.className = 'estado estado-' + String(valor).replace(/\s+/g, '-');
                etiqueta.textContent = valor;
                td.append(etiqueta);
            } else if (typeof formato === 'function') {
                td.textContent = formato(valor);
            } else {
                td.textContent = valor;
            }
            tr.append(td);
        }
        if (ent.soloLectura) {
            tbody.append(tr);
            continue;
        }
        const tdAcc = document.createElement('td');
        tdAcc.className = 'acciones';
        for (const accion of ent.acciones || []) {
            tdAcc.append(boton(accion.texto, () => accion.fn(fila)));
        }
        tdAcc.append(boton('Editar', () => editar(fila)));
        const borrar = boton('Eliminar', () => eliminar(fila));
        borrar.classList.add('peligro');
        tdAcc.append(borrar);
        tr.append(tdAcc);
        tbody.append(tr);
    }
    $('#conteo').textContent = filtro
        ? `${visibles.length} de ${filas.length} registros`
        : `${filas.length} registros ${ent.soloLectura ? 'en el reporte' : 'en la base de datos'}`;
}

function boton(texto, alHacerClic) {
    const b = document.createElement('button');
    b.type = 'button';
    b.textContent = texto;
    b.addEventListener('click', alHacerClic);
    return b;
}

// ---------------------------------------------------------------------------
// Formulario (ventana emergente) reutilizable
// ---------------------------------------------------------------------------
function leerFormulario(campos) {
    const form = $('#formulario');
    const datos = {};
    for (const c of campos) {
        const v = form.elements[c.name].value.trim();
        datos[c.name] = v === '' ? null : v;
    }
    return datos;
}

async function llenarSelect(campo, valores) {
    const select = $('#formulario').elements[campo.name];
    const opciones = await campo.opciones(valores);
    select.replaceChildren(new Option(campo.vacio || '— Seleccione —', ''));
    for (const o of opciones) select.append(new Option(o.nombre, o.id));
    const actual = valores[campo.name];
    select.value = actual === null || actual === undefined ? '' : String(actual);
}

async function abrirFormulario({ titulo, campos, valores = {}, editando = false, enviar }) {
    const contenedor = $('#campos');
    contenedor.replaceChildren();
    $('#tituloDialogo').textContent = titulo;
    $('#errorDialogo').hidden = true;
    $('#guardar').hidden = false;
    $('#cancelar').textContent = 'Cancelar';

    for (const c of campos) {
        const label = document.createElement('label');
        label.className = 'campo';
        label.append(Object.assign(document.createElement('span'), {
            textContent: c.label + (c.requerido ? ' *' : '')
        }));
        let input;
        if (c.tipo === 'select') {
            input = document.createElement('select');
        } else if (c.tipo === 'textarea') {
            input = document.createElement('textarea');
        } else {
            input = document.createElement('input');
            input.type = c.tipo || 'text';
            if (c.step) input.step = c.step;
            if (c.min !== undefined) input.min = c.min;
        }
        input.name = c.name;
        if (editando && c.soloCrear) input.disabled = true;
        if (c.tipo !== 'select') input.value = valores[c.name] ?? '';
        label.append(input);
        if (c.ayuda) label.append(Object.assign(document.createElement('small'), { textContent: c.ayuda }));
        contenedor.append(label);
    }

    try {
        for (const c of campos.filter(c => c.tipo === 'select')) await llenarSelect(c, valores);
    } catch (e) {
        aviso(e.message, true);
        return;
    }

    const form = $('#formulario');
    // Si cambia un campo del que dependen otros (cliente → direcciones), recargar esas listas
    form.onchange = async (ev) => {
        for (const c of campos.filter(c => c.dependeDe === ev.target.name)) {
            await llenarSelect(c, leerFormulario(campos));
        }
    };
    form.onsubmit = async (ev) => {
        ev.preventDefault();
        try {
            await enviar(leerFormulario(campos));
            $('#dialogo').close();
            aviso('Cambios guardados en la base de datos.');
            await mostrar(entidadActual);
        } catch (e) {
            const caja = $('#errorDialogo');
            caja.textContent = e.message;
            caja.hidden = false;
        }
    };
    $('#dialogo').showModal();
}

// ---------------------------------------------------------------------------
// Acciones CRUD
// ---------------------------------------------------------------------------
function nuevo() {
    const ent = ENTIDADES[entidadActual];
    abrirFormulario({
        titulo: `${ent.femenino ? 'Nueva' : 'Nuevo'} ${ent.singular}`,
        campos: ent.campos,
        enviar: (datos) => api('POST', ent.url, datos)
    });
}

function editar(fila) {
    const ent = ENTIDADES[entidadActual];
    abrirFormulario({
        titulo: `Editar ${ent.singular} ${fila[ent.id]}`,
        campos: ent.campos,
        valores: fila,
        editando: true,
        enviar: (datos) => api('PUT', `${ent.url}/${fila[ent.id]}`, datos)
    });
}

async function eliminar(fila) {
    const ent = ENTIDADES[entidadActual];
    const extra = entidadActual === 'solicitudes' ? ' También se eliminarán sus incidentes.' : '';
    if (!confirm(`¿Eliminar ${ent.singular} ${fila[ent.id]}?${extra}`)) return;
    try {
        await api('DELETE', `${ent.url}/${fila[ent.id]}`);
        aviso(`Se eliminó ${ent.singular} ${fila[ent.id]}.`);
        await mostrar(entidadActual);
    } catch (e) {
        aviso(e.message, true);
    }
}

// Acciones propias de las solicitudes
function asignarDomiciliario(fila) {
    abrirFormulario({
        titulo: `Asignar domiciliario · solicitud ${fila.numeroSolicitud}`,
        campos: [{
            name: 'idDomiciliario', label: 'Domiciliario disponible', tipo: 'select', requerido: true,
            opciones: opcionesDomiciliariosDisponibles,
            ayuda: 'Solo aparecen domiciliarios activos con menos de 2 solicitudes activas. Se guardará la fecha y hora de asignación y el estado pasará a Asignada.'
        }],
        valores: fila,
        enviar: (datos) => api('PUT', `/api/solicitudes/${fila.numeroSolicitud}/asignar`, datos)
    });
}

function cambiarEstado(fila) {
    abrirFormulario({
        titulo: `Cambiar estado · solicitud ${fila.numeroSolicitud}`,
        campos: [{
            name: 'idEstadoSolicitud', label: 'Nuevo estado', tipo: 'select', requerido: true,
            opciones: desdeCatalogo('estadosSolicitud'),
            ayuda: 'Flujo: Creada → Asignada → En curso → Finalizada. Se puede cancelar antes de finalizar.'
        }],
        valores: fila,
        enviar: (datos) => api('PUT', `/api/solicitudes/${fila.numeroSolicitud}/estado`, datos)
    });
}

async function verHistorial(fila) {
    try {
        const historial = await api('GET', `/api/solicitudes/${fila.numeroSolicitud}/historial`);
        mostrarTablaEnDialogo(`Historial · solicitud ${fila.numeroSolicitud}`, historial);
    } catch (e) {
        aviso(e.message, true);
    }
}

function verIncidentes(fila) {
    $('#buscar').value = String(fila.numeroSolicitud);
    mostrar('incidentes');
}

// ---------------------------------------------------------------------------
// Eventos
// ---------------------------------------------------------------------------
document.querySelectorAll('#pestanas button').forEach(b =>
    b.addEventListener('click', () => {
        $('#buscar').value = '';
        mostrar(b.dataset.entidad);
    }));
$('#buscar').addEventListener('input', pintarTabla);
$('#recargar').addEventListener('click', () => mostrar(entidadActual));
$('#nuevo').addEventListener('click', nuevo);
$('#consultarReporte').addEventListener('click', consultarReporte);
$('#cancelar').addEventListener('click', () => $('#dialogo').close());

mostrar('solicitudes');
