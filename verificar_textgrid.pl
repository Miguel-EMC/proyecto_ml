#!/usr/bin/perl
use strict;
use warnings;
use lib '.';
use TextGrid;

sub verificar_textgrid {
    my ($textgrid_path, $audio_path) = @_;
    
    print "=== VERIFICANDO TEXTGRID ===\n";
    print "Archivo: $textgrid_path\n\n";
    
    # Cargar TextGrid
    my $tg = eval { new TextGrid($textgrid_path) };
    if ($@) {
        print "ERROR: No se pudo cargar el TextGrid: $@\n";
        return 0;
    }
    
    # Información básica
    print "1. INFORMACIÓN BÁSICA:\n";
    my $bounds = $tg->getBounds();
    if (defined $bounds) {
        print "   - Duración total: " . $bounds->getDuration() . " segundos\n";
        print "   - Tiempo inicio: " . $bounds->getMin() . " segundos\n";
        print "   - Tiempo final: " . $bounds->getMax() . " segundos\n";
    }
    print "   - Número de tiers: " . $tg->count() . "\n";
    
    # Verificar cada tier
    print "\n2. ANÁLISIS DE TIERS:\n";
    my @tier_names = $tg->getTierNames();
    for my $i (0..$#tier_names) {
        my $tier_name = $tier_names[$i];
        my $tier = $tg->getTier($tier_name);
        my $num_intervals = $tier->count();
        
        print "   Tier $i: '$tier_name' ($num_intervals intervalos)\n";
        
        # Verificar continuidad temporal
        my $prev_end = 0;
        my $gaps = 0;
        my $overlaps = 0;
        
        for my $j (0..$num_intervals-1) {
            my $interval = $tier->getNodeAt($j);
            my $start = $interval->getRange()->getMin();
            my $end = $interval->getRange()->getMax();
            
            if ($start > $prev_end + 0.001) {  # Gap > 1ms
                $gaps++;
            } elsif ($start < $prev_end - 0.001) {  # Overlap > 1ms
                $overlaps++;
            }
            
            $prev_end = $end;
        }
        
        print "     - Gaps encontrados: $gaps\n";
        print "     - Overlaps encontrados: $overlaps\n";
        
        # Verificar intervalos vacíos
        my $empty_intervals = 0;
        for my $j (0..$num_intervals-1) {
            my $interval = $tier->getNodeAt($j);
            my $text = $interval->getValue();
            if (!defined $text || $text =~ /^\s*$/) {
                $empty_intervals++;
            }
        }
        print "     - Intervalos vacíos: $empty_intervals\n";
    }
    
    # Verificar audio si existe
    if (defined $audio_path && -f $audio_path) {
        print "\n3. VERIFICACIÓN DE AUDIO:\n";
        print "   - Archivo de audio encontrado: $audio_path\n";
        
        # Usar ffprobe si está disponible para obtener duración del audio
        my $audio_duration = `ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$audio_path" 2>/dev/null`;
        chomp $audio_duration if $audio_duration;
        
        if ($audio_duration && $audio_duration =~ /^\d+\.?\d*$/) {
            my $bounds = $tg->getBounds();
            my $tg_duration = defined $bounds ? $bounds->getDuration() : 0;
            my $diff = abs($audio_duration - $tg_duration);
            
            print "   - Duración del audio: $audio_duration segundos\n";
            print "   - Duración del TextGrid: $tg_duration segundos\n";
            print "   - Diferencia: $diff segundos\n";
            
            if ($diff > 1.0) {
                print "   ⚠️  ADVERTENCIA: Diferencia significativa en duración\n";
            } else {
                print "   ✓ Sincronización temporal correcta\n";
            }
        }
    } else {
        print "\n3. AUDIO:\n";
        print "   - No se encontró archivo de audio o no se especificó\n";
    }
    
    print "\n=== VERIFICACIÓN COMPLETADA ===\n";
    return 1;
}

# Usar el script
if (@ARGV < 1) {
    print "Uso: perl verificar_textgrid.pl <archivo.TextGrid> [archivo_audio]\n";
    exit 1;
}

my $textgrid_file = $ARGV[0];
my $audio_file = $ARGV[1] if @ARGV > 1;

verificar_textgrid($textgrid_file, $audio_file);