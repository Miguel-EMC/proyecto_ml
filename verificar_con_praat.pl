#!/usr/bin/perl
use strict;
use warnings;

sub verificar_con_praat {
    my ($textgrid_path, $audio_path) = @_;
    
    # Convertir rutas relativas a absolutas
    use Cwd 'abs_path';
    $textgrid_path = abs_path($textgrid_path) if defined $textgrid_path;
    $audio_path = abs_path($audio_path) if defined $audio_path && -f $audio_path;
    
    print "=== VERIFICACIÓN CON PRAAT ===\n";
    
    # Verificar si Praat está disponible
    my $praat_path = "./praat";
    unless (-x $praat_path) {
        print "ERROR: Praat no encontrado en $praat_path\n";
        return 0;
    }
    
    # Crear script de Praat temporal
    my $praat_script = "/tmp/verificar_textgrid.praat";
    open my $fh, '>', $praat_script or die "No se pudo crear script temporal: $!";
    
    print $fh qq{
# Script de verificación TextGrid
textgrid_path\$ = "$textgrid_path"
audio_path\$ = "$audio_path"

# Cargar TextGrid
textGrid = Read from file: textgrid_path\$
selectObject: textGrid

# Información básica
numberOfTiers = Get number of tiers
totalDuration = Get total duration

writeInfoLine: "=== VERIFICACIÓN PRAAT ==="
writeInfoLine: "Archivo: ", textgrid_path\$
writeInfoLine: ""
writeInfoLine: "INFORMACIÓN BÁSICA:"
writeInfoLine: "- Número de tiers: ", numberOfTiers
writeInfoLine: "- Duración total: ", fixed\$(totalDuration, 3), " segundos"

# Verificar cada tier
for tier from 1 to numberOfTiers
    selectObject: textGrid
    tierName\$ = Get tier name: tier
    numberOfIntervals = Get number of intervals: tier
    
    writeInfoLine: ""
    writeInfoLine: "TIER ", tier, ": '", tierName\$, "'"
    writeInfoLine: "- Intervalos: ", numberOfIntervals
    
    # Verificar continuidad temporal y contenido
    empty_intervals = 0
    for interval from 1 to numberOfIntervals
        selectObject: textGrid
        label\$ = Get label of interval: tier, interval
        if label\$ = ""
            empty_intervals = empty_intervals + 1
        endif
    endfor
    
    writeInfoLine: "- Intervalos vacíos: ", empty_intervals
endfor

# Si hay archivo de audio, verificar sincronización
if fileReadable(audio_path\$)
    sound = Read from file: audio_path\$
    selectObject: sound
    audioDuration = Get total duration
    
    writeInfoLine: ""
    writeInfoLine: "SINCRONIZACIÓN:"
    writeInfoLine: "- Duración audio: ", fixed\$(audioDuration, 3), " segundos"
    writeInfoLine: "- Duración TextGrid: ", fixed\$(totalDuration, 3), " segundos"
    writeInfoLine: "- Diferencia: ", fixed\$(abs(audioDuration - totalDuration), 3), " segundos"
    
    if abs(audioDuration - totalDuration) > 1.0
        writeInfoLine: "⚠️  ADVERTENCIA: Diferencia temporal significativa"
    else
        writeInfoLine: "✓ Sincronización correcta"
    endif
    
    removeObject: sound
endif

removeObject: textGrid
writeInfoLine: ""
writeInfoLine: "=== VERIFICACIÓN COMPLETADA ==="
};
    
    close $fh;
    
    # Ejecutar Praat
    print "Ejecutando verificación con Praat...\n";
    my $result = system("$praat_path --run $praat_script");
    
    # Limpiar archivo temporal
    unlink $praat_script;
    
    return $result == 0;
}

# Usar el script
if (@ARGV < 1) {
    print "Uso: perl verificar_con_praat.pl <archivo.TextGrid> [archivo_audio]\n";
    exit 1;
}

my $textgrid_file = $ARGV[0];
my $audio_file = $ARGV[1] || "";

verificar_con_praat($textgrid_file, $audio_file);