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

const opcionesDomiciliariosActivos = async () =>
    (await api('GET', '/api/domiciliarios'))
        .filter(d => d.nombreEstadoDomiciliario === 'Activo')
        .map(d => ({
            id: d.numeroIdentificacion,
            nombre: `${d.codigoUnico} · ${d.nombre} ${d.apellido_Paterno} (${d.nombreMedioTransporte})`
        }));

const opcionesSolicitudes = async () =>
    (await api('GET', '/api/solicitudes')).map(s => ({
        id: s.numeroSolicitud, nombre: `${s.numeroSolicitud} · ${s.descripcion}`
    }));

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
            { name: 'montoTotal', label: 'Monto total (COP)', tipo: 'number', requerido: true, step: '0.01', min: 0 },
            { name: 'idMetodoPago', label: 'Método de pago', tipo: 'select', requerido: true, opciones: desdeCatalogo('metodosPago') }
        ],
        acciones: [
            { texto: 'Asignar', fn: asignarDomiciliario },
            { texto: 'Estado', fn: cambiarEstado },
            { texto: 'Incidentes', fn: verIncidentes }
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
            ['nombreEstadoDomiciliario', 'Estado', 'estado']
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
            { name: 'numeroSolicitud', label: 'Solicitud', tipo: 'select', requerido: true, opciones: opcionesSolicitudes },
            { name: 'idTipoIncidente', label: 'Tipo de incidente', tipo: 'select', requerido: true, opciones: desdeCatalogo('tiposIncidente') },
            { name: 'descripcion', label: 'Descripción', tipo: 'textarea', requerido: true },
            { name: 'fechaIncidente', label: 'Fecha', tipo: 'date', ayuda: 'Vacío = fecha de hoy.' },
            { name: 'horaIncidente', label: 'Hora', tipo: 'time', ayuda: 'Vacío = hora actual.' }
        ]
    }
};

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
    trEnc.append(Object.assign(document.createElement('th'), { textContent: 'Acciones' }));
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
        : `${filas.length} registros en la base de datos`;
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
            name: 'idDomiciliario', label: 'Domiciliario (solo activos)', tipo: 'select', requerido: true,
            opciones: opcionesDomiciliariosActivos,
            ayuda: 'Se guardará la fecha y hora de asignación y el estado pasará a Asignada.'
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
$('#cancelar').addEventListener('click', () => $('#dialogo').close());

mostrar('solicitudes');
