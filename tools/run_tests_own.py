#!/usr/bin/env python3
"""Ejecuta programas en la CPU de circuit/smips.circ y compara la salida del TTY con la de MARS.

Uso: python3 tools/run_tests.py [--circuito archivo.circ] [fuente.asm ...]
Sin fuentes prueba programs/*.asm y tests/*.asm. Necesita Java 21, MARS (MARS_JAR),
Logisim Evolution 5.0.0 (LOGISIM_JAR) y, solo si la CPU tiene entidades VHDL, Questa con licencia
(QUESTA_BIN, SALT_LICENSE_SERVER).
"""
from pathlib import Path
import argparse
import os
import subprocess
import sys
import tempfile
import threading

ROOT = Path(__file__).resolve().parent.parent
HERE = ROOT/'tools'

def variable(nombre):
    r"""Valor de una variable de entorno sin espacios ni comillas alrededor
    (en cmd, set X="C:\ruta con espacios" guarda tambien las comillas)."""
    return os.environ.get(nombre, '').strip().strip('"\'').strip() or None


def buscar(nombre, candidatos):
    """La variable de entorno si apunta a un archivo, si no el primer candidato que exista.
    Devuelve (ruta o None, lista de rutas probadas)."""
    probados = [Path(variable(nombre))] if variable(nombre) else []
    for patron in candidatos:
        probados += sorted(patron.parent.glob(patron.name)) or [patron]
    return next((str(c) for c in probados if c.is_file()), None), probados


# En Windows el instalador deja Logisim en "Program Files\logisim-evolution" (o en su subcarpeta app).
# Un Python de 32 bits ve ProgramFiles como "Program Files (x86)", por eso se prueban todas.
WINDOWS = list(dict.fromkeys(Path(d)/'logisim-evolution' for d in (
    os.environ.get('ProgramW6432'), os.environ.get('ProgramFiles'), os.environ.get('ProgramFiles(x86)'),
    r'C:\Program Files') if d))
JAR, PROBADOS_JAR = buscar('LOGISIM_JAR', [
    Path('/snap/logisim-evolution-snapcraft/current/jar/logisim-evolution.jar'),
    Path.home()/'Apps/logisim/logisim-evolution*.jar',
    *(d/'logisim-evolution*.jar' for d in WINDOWS), *(d/'app/logisim-evolution*.jar' for d in WINDOWS)])
MARS, PROBADOS_MARS = buscar('MARS_JAR', [Path.home()/'Apps/mars/Mars4_5.jar', Path.home()/'Apps/mars/Mars*.jar'])
JAVA = os.environ.get('JAVA', 'java')
CICLOS_MAX = 60000  # con 4-5 ciclos por instruccion, el programa mas largo usa unos 8000
PASOS_MARS = 1000000  # sin limite, MARS se queda colgado para siempre si el programa no termina
SEGUNDOS_MARS = 60
# Tiempo maximo de la placa: arranque + por programa (sin VHDL ~1000 ciclos/s; con Questa es mucho mas lento).
SEGUNDOS_PLACA = int(os.environ.get('SEGUNDOS_PLACA', '0')) or None
# Si en este tiempo no termina el primer programa, se avisa (normalmente tarda unos segundos).
SEGUNDOS_AVISO = int(os.environ.get('SEGUNDOS_AVISO', '60'))


def normalizar(texto):
    lineas = [linea.rstrip() for linea in texto.split('\n')]
    while lineas and not lineas[-1]:
        lineas.pop()
    return '\n'.join(lineas)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--circuito', type=Path, default=ROOT/'circuit/smips.circ')
    parser.add_argument('fuentes', type=Path, nargs='*')
    args = parser.parse_args()
    for nombre, ruta, probados, var in (('Logisim Evolution 5.0.0', JAR, PROBADOS_JAR, 'LOGISIM_JAR'),
                                        ('MARS', MARS, PROBADOS_MARS, 'MARS_JAR')):
        if ruta is None:
            sys.exit(f'No se encuentra el .jar de {nombre}. Se busco en:\n' +
                     ''.join(f'  {p}\n' for p in probados) +
                     f'Define la variable {var} con la ruta completa del .jar, por ejemplo:\n'
                     f'  cmd:        set {var}=C:\\ruta\\al\\archivo.jar\n'
                     f'  PowerShell: $env:{var} = "C:\\ruta\\al\\archivo.jar"')
    fuentes = args.fuentes or sorted((ROOT/'programs').glob('*.asm')) + sorted((ROOT/'tests').glob('*.asm'))
    with tempfile.TemporaryDirectory(prefix='smips-probar-') as directorio:
        directorio = Path(directorio)
        imagenes, esperado = {}, {}
        for fuente in fuentes:
            imagen = directorio/(fuente.stem + '.hex')
            print(f'MARS: {os.path.relpath(fuente)}', file=sys.stderr, flush=True)
            ensamblado = subprocess.run([sys.executable, str(HERE/'assemble.py'), str(fuente), '-o', str(imagen)],
                                        capture_output=True, text=True, stdin=subprocess.DEVNULL)
            if ensamblado.returncode:
                sys.exit(f'No se pudo ensamblar {fuente}:\n{ensamblado.stdout}{ensamblado.stderr}')
            if 'Aviso' in ensamblado.stdout:
                print(ensamblado.stdout.rstrip(), flush=True)
            try:
                mars = subprocess.run([JAVA, '-jar', MARS, 'nc', 'mc', 'CompactTextAtZero', str(PASOS_MARS), str(fuente)],
                                      capture_output=True, text=True, check=True, stdin=subprocess.DEVNULL,
                                      timeout=SEGUNDOS_MARS)
            except subprocess.TimeoutExpired:
                sys.exit(f'MARS no termino {fuente} en {SEGUNDOS_MARS} s')
            if 'maximum step limit' in mars.stdout:
                sys.exit(f'{fuente} no termina en MARS ({PASOS_MARS} instrucciones): bucle infinito o falta syscall 10')
            imagenes[str(imagen)] = fuente
            esperado[fuente] = normalizar(mars.stdout)
        print(f'Ejecutando {len(fuentes)} programas en la placa...', flush=True)
        orden = [JAVA, f'-Djava.util.prefs.userRoot={directorio}/prefs', '--class-path', JAR,
                 str(HERE/'Run.java'), str(args.circuito.resolve()), str(CICLOS_MAX), '0', *imagenes]
        # Cada programa se informa en cuanto termina (la cosimulacion es lenta).
        # stderr de Java se lee en un hilo aparte y se muestra en vivo (un PIPE que nadie lee bloquea a Java
        # cuando se llena); tambien se guarda para repetir el final si la ejecucion falla.
        proceso = subprocess.Popen(orden, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL,
                                   text=True, errors='replace')
        error = []

        def leer_errores():
            for linea in proceso.stderr:
                error.append(linea)
                print(f'[java] {linea}', end='', file=sys.stderr, flush=True)

        lector = threading.Thread(target=leer_errores, daemon=True)
        lector.start()
        limite = SEGUNDOS_PLACA or 120 + 300*len(fuentes)
        expirado = threading.Event()

        def matar():
            expirado.set()
            proceso.kill()

        # daemon: si el script falla, no se queda esperando al temporizador antes de salir.
        vigilante = threading.Timer(limite, matar)
        vigilante.daemon = True
        vigilante.start()
        resultados, fallos = [], 0

        def avisar_arranque():
            if not resultados and proceso.poll() is None:
                print(f'Aviso: tras {SEGUNDOS_AVISO} s la placa aun no termino el primer programa (aqui tarda unos segundos).\n'
                      '  Probablemente Logisim esta esperando en un cuadro de dialogo (busca con Alt+Tab),\n'
                      '  o LOGISIM_JAR no es Logisim Evolution 5.0.0. Ctrl+C para cancelar.', file=sys.stderr, flush=True)

        aviso = threading.Timer(SEGUNDOS_AVISO, avisar_arranque)
        aviso.daemon = True
        aviso.start()
        try:
            for linea in proceso.stdout:
                if not linea.startswith('RESULTADO'):
                    if linea.strip():
                        print(f'[java] {linea}', end='', file=sys.stderr, flush=True)
                    continue
                _, imagen, detenido, ciclos, pc, tty = linea.rstrip('\n').split('\t')
                resultados.append(imagen)
                fuente = imagenes[imagen]
                salida = normalizar(bytes.fromhex(tty).decode())
                ok = detenido == 'true' and salida == esperado[fuente]
                fallos += not ok
                print(f'{"OK   " if ok else "FALLO"} {os.path.relpath(fuente)}  ({ciclos} ciclos)', flush=True)
                if not ok:
                    print(f'  detenido={detenido} (MEM_ADDR final 0x{pc})\n  esperado (MARS):\n    ' + esperado[fuente].replace('\n', '\n    ') +
                          '\n  obtenido (TTY):\n    ' + salida.replace('\n', '\n    '), flush=True)
            codigo = proceso.wait()
        finally:
            vigilante.cancel()
            aviso.cancel()
            if proceso.poll() is None:  # Ctrl+C o excepcion: no dejar Java colgado
                proceso.kill()
                proceso.wait()
        lector.join(5)
        if codigo or len(resultados) != len(fuentes):
            causa = f'se supero el limite de {limite} s (SEGUNDOS_PLACA)' if expirado.is_set() else f'codigo {codigo}'
            sys.exit(f'Fallo la ejecucion ({causa}):\n{"".join(error)[-4000:]}')
    print(f'\n{len(resultados) - fallos}/{len(resultados)} correctos')
    sys.exit(1 if fallos else 0)


if __name__ == '__main__':
    main()
