#!/usr/bin/perl

=head1 SISTEMA ASR - ALINEACION Y CLASIFICACION DE ERRORES

Proyecto academico para alineacion automatica de transcripciones con audio
usando informacion ASR, clasificacion de errores y modelado HMM.

Uso:
  perl asr_system.pl train
  perl asr_system.pl validate

=cut

use strict;
use warnings;
use utf8;
use JSON;
use List::Util qw(min max sum);
use File::Basename;
use lib '.';
use TextGrid;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# Configuracion
my $CONFIG = {
    training_dir => 'data/training',
    validation_dir => 'data/validation',
    model_file => 'results/modelo_hmm.json',
    debug => 0,
};

# Etiquetas de error y estados HMM
my @VISIBLE_LABELS = qw(<M> <D> <I> <T> <A1> <A2> <A3> <A4> <A5> <S>);
my @HIDDEN_STATES = qw(<MAT> <DEL> <INS> <TRA> <SUS>);
my %LABEL_TO_STATE = (
    '<M>' => '<MAT>', '<D>' => '<DEL>', '<I>' => '<INS>', '<T>' => '<TRA>',
    '<A1>' => '<SUS>', '<A2>' => '<SUS>', '<A3>' => '<SUS>', '<A4>' => '<SUS>', '<A5>' => '<SUS>', '<S>' => '<SUS>',
);

#############################################################################
# FUNCIONES AUXILIARES
#############################################################################

sub levenshtein_distance {
    my ($str1, $str2) = @_;
    my $len1 = length($str1);
    my $len2 = length($str2);

    return $len2 if $len1 == 0;
    return $len1 if $len2 == 0;

    my @matrix;
    for my $i (0..$len1) { $matrix[$i][0] = $i; }
    for my $j (0..$len2) { $matrix[0][$j] = $j; }

    for my $i (1..$len1) {
        for my $j (1..$len2) {
            my $cost = (substr($str1, $i-1, 1) eq substr($str2, $j-1, 1)) ? 0 : 1;
            $matrix[$i][$j] = min(
                $matrix[$i-1][$j] + 1,
                $matrix[$i][$j-1] + 1,
                $matrix[$i-1][$j-1] + $cost
            );
        }
    }
    return $matrix[$len1][$len2];
}

sub safe_log {
    my ($prob) = @_;
    return -999999 if $prob <= 0;
    return log($prob);
}

#############################################################################
# NORMALIZACIÓN DE TEXTO
#############################################################################

sub normalize_text {
    my ($text) = @_;
    return '' unless defined $text;

    # Procesar códigos Unicode primero (CRUCIAL para corregir el problema)
    $text =~ s/\\u00f3/ó/g;  # ó
    $text =~ s/\\u00e1/á/g;  # á
    $text =~ s/\\u00e9/é/g;  # é
    $text =~ s/\\u00ed/í/g;  # í
    $text =~ s/\\u00fa/ú/g;  # ú
    $text =~ s/\\u00f1/ñ/g;  # ñ
    $text =~ s/\\u00e7/ç/g;  # ç
    $text =~ s/\\u([0-9a-fA-F]{4})/chr(hex($1))/ge;

    # Remover HTML y entidades
    $text =~ s/&quot;/"/g;
    $text =~ s/&amp;/&/g;
    $text =~ s/&[a-zA-Z0-9#]+;//g;
    $text =~ s/<[^>]+>//g;

    # Convertir a minúsculas
    $text = lc($text);

    # Convertir caracteres acentuados
    $text =~ s/[áàâäãå]/a/g;
    $text =~ s/[éèêë]/e/g;
    $text =~ s/[íìîï]/i/g;
    $text =~ s/[óòôöõø]/o/g;
    $text =~ s/[úùûü]/u/g;
    $text =~ s/[ñ]/n/g;
    $text =~ s/[ç]/c/g;

    # Conversiones del diccionario
    my %conversions = (
        '-mil' => '.000',
        'mil' => '1000',
        'millones' => '000000',
        'millón' => '000000',
        'estados unidos' => 'ee uu',
        'eeuu' => 'ee uu',
        'cero' => '<NUM>',
        'uno' => '<NUM>',
        'dos' => '<NUM>',
        'tres' => '<NUM>',
        'cuatro' => '<NUM>',
        'cinco' => '<NUM>',
        'seis' => '<NUM>',
        'siete' => '<NUM>',
        'ocho' => '<NUM>',
        'nueve' => '<NUM>',
        'diez' => '<NUM>',
        'once' => '<NUM>',
        'doce' => '<NUM>',
        'trece' => '<NUM>',
        'catorce' => '<NUM>',
        'quince' => '<NUM>',
        'dieciseis' => '<NUM>',
        'dieciséis' => '<NUM>',
        'diecisiete' => '<NUM>',
        'dieciocho' => '<NUM>',
        'diecinueve' => '<NUM>',
        'veinte' => '<NUM>',
        'treinta' => '<NUM>',
        'cuarenta' => '<NUM>',
        'cincuenta' => '<NUM>',
        'sesenta' => '<NUM>',
        'setenta' => '<NUM>',
        'ochenta' => '<NUM>',
        'noventa' => '<NUM>',
        'cien' => '<NUM>',
        'ciento' => '<NUM>',
        'doscientos' => '<NUM>',
        'doscientas' => '<NUM>',
        'trescientos' => '<NUM>',
        'trescientas' => '<NUM>',
        'trecientos' => '<NUM>',
        'cuatrocientos' => '<NUM>',
        'cuatrocientas' => '<NUM>',
        'quinientos' => '<NUM>',
        'quinientas' => '<NUM>',
        'seiscientos' => '<NUM>',
        'seiscientas' => '<NUM>',
        'setecientos' => '<NUM>',
        'setecientas' => '<NUM>',
        'ochocientos' => '<NUM>',
        'ochocientas' => '<NUM>',
        'novecientos' => '<NUM>',
        'novecientas' => '<NUM>',
        'cientos' => '<NUM>',
        'miles' => '<NUM>',
        'millón' => '<NUM>',
        'billón' => '<NUM>',
        'media' => '<NUM>',
        'medio' => '<NUM>',
        'docena' => '<NUM>',
        'decena' => '<NUM>',
        'centena' => '<NUM>',
        'primero' => '<NUM>',
        'primera' => '<NUM>',
        'segundo' => '<NUM>',
        'tercero' => '<NUM>',
        'cuarto' => '<NUM>',
        'quinto' => '<NUM>',
        'sexto' => '<NUM>',
        'séptimo' => '<NUM>',
        'octavo' => '<NUM>',
        'noveno' => '<NUM>',
        'décimo' => '<NUM>',
        'veintiuno' => '<NUM>',
        'veintidos' => '<NUM>',
        'veintitres' => '<NUM>',
        'veinticuatro' => '<NUM>',
        'veinticinco' => '<NUM>',
        'veintiseis' => '<NUM>',
        'veintisiete' => '<NUM>',
        'veintiocho' => '<NUM>',
        'veintinueve' => '<NUM>',
    );

    foreach my $key (keys %conversions) {
        $text =~ s/\b\Q$key\E\b/$conversions{$key}/gi;
    }

    # Convertir números compuestos de múltiples palabras
    $text =~ s/\b(doscientos|trescientos|cuatrocientos|quinientos|seiscientos|setecientos|ochocientos|novecientos)\s+(uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|trece|catorce|quince|dieciseis|diecisiete|dieciocho|diecinueve|veinte|veintiuno|veintidos|veintitres|veinticuatro|veinticinco|veintiseis|veintisiete|veintiocho|veintinueve|treinta|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa)\b/<NUM>/gi;

    # Números de 21-99 con "y"
    $text =~ s/\b(veinte|treinta|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa)\s+y\s+(uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve)\b/<NUM>/gi;

    # Convertir números y decimales a <NUM>
    $text =~ s/\b\d+([.,]\d+)*\b/<NUM>/g;
    # Convertir números con separadores de miles
    $text =~ s/\b\d{1,3}([\.,]\d{3})+\b/<NUM>/g;
    # Convertir porcentajes
    $text =~ s/\b\d+([.,]\d+)*\s*%\b/<NUM>/g;

    # Limpiar puntuación y espacios
    $text =~ s/[^\p{L}\p{N}\s'<>-]/ /g;
    $text =~ s/\s+/ /g;
    $text =~ s/^\s+|\s+$//g;

    return $text;
}

#############################################################################
# CARGA DE DATOS
#############################################################################

sub load_textgrid {
    my ($file_path) = @_;

    my $textgrid = TextGrid->new();
    $textgrid->read($file_path);
    return $textgrid;
}

sub extract_ipu_segments {
    my ($textgrid) = @_;

    my @tier_names = $textgrid->getTierNames();
    my $ipu_tier;

    foreach my $tier_name ('IPU', 'Pausas', 'ipu', 'pausas') {
        if (grep { $_ eq $tier_name } @tier_names) {
            $ipu_tier = $textgrid->getTier($tier_name);
            last;
        }
    }

    unless ($ipu_tier) {
        die "Tier IPU/Pausas no encontrado. Tiers disponibles: " . join(", ", @tier_names) . "\n";
    }

    my @segments;
    my $nodes = $ipu_tier->getList();

    foreach my $node (@$nodes) {
        my $text = $node->getValue();
        next if (!defined $text || $text eq '' || $text =~ /^[#_@\s]*$/);

        push @segments, {
            start_time => $node->getRange()->getMin(),
            end_time => $node->getRange()->getMax(),
            text => normalize_text($text),
            original_text => $text
        };
    }

    return \@segments;
}

sub load_html_transcriptions {
    my ($dataset_dir) = @_;

    my @transcriptions;
    opendir(my $dh, $dataset_dir) or die "No se puede abrir $dataset_dir: $!";
    my @html_files = sort grep { /\.html$/ } readdir($dh);
    closedir($dh);

    foreach my $html_file (@html_files) {
        my $file_path = "$dataset_dir/$html_file";
        my $content = extract_text_from_html($file_path);

        if ($content && $content ne '') {
            push @transcriptions, {
                file => $html_file,
                text => normalize_text($content),
                original_text => $content
            };
        }
    }

    return \@transcriptions;
}

sub extract_text_from_html {
    my ($file_path) = @_;

    open(my $fh, '<:encoding(UTF-8)', $file_path) or die "No se puede abrir $file_path: $!";
    my $content = do { local $/; <$fh> };
    close($fh);

    # Extraer de JSON-LD
    if ($content =~ /"articleBody":\s*"([^"]+)"/s) {
        my $text = $1;
        $text =~ s/\\n/\n/g;
        $text =~ s/\\"/"/g;
        $text =~ s/\\\\/\\/g;
        return $text;
    }

    # Extraer de párrafos
    my @paragraphs;
    while ($content =~ /<p[^>]*>(.*?)<\/p>/gis) {
        my $para = $1;
        $para =~ s/<[^>]+>//g;
        push @paragraphs, $para if $para =~ /\S/;
    }
    return join(' ', @paragraphs) if @paragraphs;
    if ($content =~ /<meta\s+name="description"\s+content="([^"]+)"/i) {
        return $1;
    }

    return '';
}

sub load_align_file {
    my ($file_path) = @_;

    open(my $fh, '<:encoding(UTF-8)', $file_path) or die "No se puede abrir $file_path: $!";
    my @lines = <$fh>;
    close($fh);

    return {} unless @lines >= 2;

    chomp(@lines);
    my @asr_words = split(/\s+/, normalize_text($lines[0]));
    my @ref_words = split(/\s+/, normalize_text($lines[1]));

    return {
        asr_words => \@asr_words,
        reference_words => \@ref_words,
    };
}

#############################################################################
# ALINEACIÓN DE TEXTO
#############################################################################

sub align_transcriptions_with_ipu {
    my ($transcriptions, $ipu_segments) = @_;

    # Concatenar texto completo
    my $full_transcription = join(' ', map { $_->{text} } @$transcriptions);
    my @transcription_words = split(/\s+/, $full_transcription);

    my $full_ipu_text = join(' ', map { $_->{text} } @$ipu_segments);
    my @ipu_words = split(/\s+/, $full_ipu_text);


    # Alineación
    my $alignment = align_word_sequences(\@transcription_words, \@ipu_words);
    my $timed_alignment = map_alignment_to_time($alignment, $ipu_segments);

    return $timed_alignment;
}

sub align_word_sequences {
    my ($seq1, $seq2) = @_;

    my $len1 = scalar(@$seq1);
    my $len2 = scalar(@$seq2);

    my @dp;
    my @traceback;

    # Inicializar matriz
    for my $i (0..$len1) {
        for my $j (0..$len2) {
            $dp[$i][$j] = ($i == 0 && $j == 0) ? 0 : -999999;
            $traceback[$i][$j] = '';
        }
    }

    # Primera fila y columna
    for my $i (1..$len1) {
        $dp[$i][0] = $dp[$i-1][0] - 2;
        $traceback[$i][0] = 'delete';
    }
    for my $j (1..$len2) {
        $dp[0][$j] = $dp[0][$j-1] - 2;
        $traceback[0][$j] = 'insert';
    }

    # Llenar matriz
    for my $i (1..$len1) {
        for my $j (1..$len2) {
            my $similarity = calculate_word_similarity($seq1->[$i-1], $seq2->[$j-1]);

            my $match_score = $dp[$i-1][$j-1] + $similarity;
            my $insert_score = $dp[$i][$j-1] - 2;
            my $delete_score = $dp[$i-1][$j] - 2;

            if ($match_score >= $insert_score && $match_score >= $delete_score) {
                $dp[$i][$j] = $match_score;
                $traceback[$i][$j] = 'match';
            } elsif ($insert_score >= $delete_score) {
                $dp[$i][$j] = $insert_score;
                $traceback[$i][$j] = 'insert';
            } else {
                $dp[$i][$j] = $delete_score;
                $traceback[$i][$j] = 'delete';
            }
        }
    }

    # Recuperar alineación
    my @alignment;
    my ($i, $j) = ($len1, $len2);

    while ($i > 0 || $j > 0) {
        my $operation = $traceback[$i][$j];

        if ($operation eq 'match' && $i > 0 && $j > 0) {
            unshift @alignment, {
                operation => 'match',
                word1 => $seq1->[$i-1],
                word2 => $seq2->[$j-1],
                similarity => calculate_word_similarity($seq1->[$i-1], $seq2->[$j-1])
            };
            $i--; $j--;
        } elsif ($operation eq 'insert' && $j > 0) {
            unshift @alignment, {
                operation => 'insert',
                word1 => '',
                word2 => $seq2->[$j-1],
                similarity => 0
            };
            $j--;
        } elsif ($operation eq 'delete' && $i > 0) {
            unshift @alignment, {
                operation => 'delete',
                word1 => $seq1->[$i-1],
                word2 => '',
                similarity => 0
            };
            $i--;
        } else {
            last;
        }
    }

    return \@alignment;
}

sub calculate_word_similarity {
    my ($word1, $word2) = @_;

    return 5 if $word1 eq $word2;
    return -3 if !$word1 || !$word2;

    if ($word1 eq '<NUM>' && $word2 =~ /^\d+$/) { return 4; }
    if ($word2 eq '<NUM>' && $word1 =~ /^\d+$/) { return 4; }

    my $distance = levenshtein_distance($word1, $word2);
    my $max_len = max(length($word1), length($word2));

    return 0 if $max_len == 0;

    my $similarity = 1 - ($distance / $max_len);

    if ($similarity > 0.8) { return 3; }
    elsif ($similarity > 0.6) { return 2; }
    elsif ($similarity > 0.4) { return 1; }
    elsif ($similarity > 0.2) { return 0; }
    else { return -1; }
}

sub map_alignment_to_time {
    my ($alignment, $ipu_segments) = @_;

    my @timed_segments;
    my $current_ipu_index = 0;
    my $word_position = 0;

    foreach my $align_item (@$alignment) {
        next if $align_item->{operation} eq 'delete';

        while ($current_ipu_index < @$ipu_segments) {
            my $ipu_segment = $ipu_segments->[$current_ipu_index];
            my @ipu_words = split(/\s+/, $ipu_segment->{text});

            if ($word_position < @ipu_words) {
                my $segment_duration = $ipu_segment->{end_time} - $ipu_segment->{start_time};
                my $word_duration = @ipu_words > 0 ? $segment_duration / @ipu_words : 0;
                my $word_start = $ipu_segment->{start_time} + ($word_position * $word_duration);
                my $word_end = $word_start + $word_duration;

                my $word_text = ($align_item->{operation} eq 'match') ?
                               $align_item->{word1} : $align_item->{word2};

                push @timed_segments, {
                    text => $word_text,
                    start_time => $word_start,
                    end_time => $word_end,
                    alignment_info => $align_item
                };

                $word_position++;
                last;
            } else {
                $current_ipu_index++;
                $word_position = 0;
            }
        }
    }

    return \@timed_segments;
}

#############################################################################
# CLASIFICACIÓN DE ERRORES
#############################################################################

sub is_number_word {
    my ($word) = @_;
    my %number_words = (
        'cero' => 1, 'uno' => 1, 'dos' => 1, 'tres' => 1, 'cuatro' => 1, 'cinco' => 1,
        'seis' => 1, 'siete' => 1, 'ocho' => 1, 'nueve' => 1, 'diez' => 1, 'once' => 1,
        'doce' => 1, 'trece' => 1, 'catorce' => 1, 'quince' => 1, 'dieciseis' => 1,
        'dieciséis' => 1, 'diecisiete' => 1, 'dieciocho' => 1, 'diecinueve' => 1,
        'veinte' => 1, 'veintiuno' => 1, 'veintidos' => 1, 'veintitres' => 1,
        'veinticuatro' => 1, 'veinticinco' => 1, 'veintiseis' => 1, 'veintisiete' => 1,
        'veintiocho' => 1, 'veintinueve' => 1, 'treinta' => 1, 'cuarenta' => 1,
        'cincuenta' => 1, 'sesenta' => 1, 'setenta' => 1, 'ochenta' => 1, 'noventa' => 1,
        'cien' => 1, 'ciento' => 1, 'doscientos' => 1, 'doscientas' => 1, 'trescientos' => 1, 'trescientas' => 1, 'trecientos' => 1, 'cuatrocientos' => 1, 'cuatrocientas' => 1,
        'quinientos' => 1, 'quinientas' => 1, 'seiscientos' => 1, 'seiscientas' => 1, 'setecientos' => 1, 'setecientas' => 1, 'ochocientos' => 1, 'ochocientas' => 1,
        'novecientos' => 1, 'novecientas' => 1, 'mil' => 1, 'miles' => 1, 'millon' => 1, 'millón' => 1, 'millones' => 1, 'billón' => 1,
        'cientos' => 1, 'media' => 1, 'medio' => 1, 'docena' => 1, 'decena' => 1, 'centena' => 1,
        'primero' => 1, 'primera' => 1, 'segundo' => 1, 'tercero' => 1, 'cuarto' => 1, 'quinto' => 1,
        'sexto' => 1, 'séptimo' => 1, 'octavo' => 1, 'noveno' => 1, 'décimo' => 1
    );

    return exists $number_words{lc($word)};
}

sub detect_real_errors {
    my ($timed_segments, $transcription_text) = @_;

    # Crear índice de todas las palabras en la transcripción (normalizadas)
    my @transcription_words = split(/\s+/, normalize_text($transcription_text));
    my %transcription_index;
    foreach my $word (@transcription_words) {
        $transcription_index{$word} = 1 if $word ne '';
    }

    my @real_errors;
    my @transcription_tier_data;

    foreach my $segment (@$timed_segments) {
        my $align_info = $segment->{alignment_info};
        my $operation = $align_info->{operation};
        my $transcription_word = $align_info->{word1} || '';
        my $ipu_word = $align_info->{word2} || '';

        # Para el tier de transcripción HTML
        if ($transcription_word) {
            push @transcription_tier_data, {
                start_time => $segment->{start_time},
                end_time => $segment->{end_time},
                text => $transcription_word
            };
        }

        # CORRECCIÓN: Verificar palabras del IPU contra el índice de transcripción
        # Solo marcar como error si la palabra NO está en la transcripción
        if ($operation eq 'insert' && $ipu_word) {
            # NUNCA marcar números como errores
            my $original_ipu = $ipu_word;
            my @original_words = split(/\s+/, lc($original_ipu));
            my $contains_number = 0;

            foreach my $orig_word (@original_words) {
                if ($orig_word =~ /^\d+([.,]\d+)*$/ || is_number_word($orig_word)) {
                    $contains_number = 1;
                    last;
                }
            }

            my $normalized_ipu = normalize_text($ipu_word);
            if ($normalized_ipu =~ /<NUM>/) {
                $contains_number = 1;
            }
            next if $contains_number;

            my @ipu_words = split(/\s+/, normalize_text($ipu_word));
            my $found_in_transcription = 0;

            # Verificar cada palabra del segmento IPU
            foreach my $word (@ipu_words) {
                next if $word eq '' || $word =~ /^-+$/;
                if ($word eq '<NUM>' || $word =~ /^\d+([.,]\d+)*$/) {
                    $found_in_transcription = 1;
                    last;
                }
                if (exists $transcription_index{$word}) {
                    $found_in_transcription = 1;
                    last;
                }
            }

            # Solo marcar como error si NINGUNA palabra está en la transcripción
            if (!$found_in_transcription) {
                push @real_errors, {
                    start_time => $segment->{start_time},
                    end_time => $segment->{end_time},
                    ipu_word => $ipu_word,
                    error_type => 'audio_only'  # Palabra que aparece solo en el audio
                };
            }
        }
        # También verificar matches con baja similitud
        elsif ($operation eq 'match' && $ipu_word && $transcription_word) {
            my $similarity = $align_info->{similarity} || 0;
            my $original_ipu = $ipu_word;
            my @original_words = split(/\s+/, lc($original_ipu));
            my $contains_number = 0;

            foreach my $orig_word (@original_words) {
                if ($orig_word =~ /^\d+([.,]\d+)*$/ || is_number_word($orig_word)) {
                    $contains_number = 1;
                    last;
                }
            }

            # También verificar versión normalizada
            my $normalized_ipu = normalize_text($ipu_word);
            if ($normalized_ipu =~ /<NUM>/) {
                $contains_number = 1;
            }

            # Si contiene números, no marcar como error
            next if $contains_number;

            my @ipu_words = split(/\s+/, normalize_text($ipu_word));
            my $found_in_transcription = 0;

            foreach my $word (@ipu_words) {
                next if $word eq '' || $word =~ /^-+$/;
                # Si es <NUM>, considerarlo siempre como encontrado
                if ($word eq '<NUM>' || $word =~ /^\d+([.,]\d+)*$/) {
                    $found_in_transcription = 1;
                    last;
                }
                if (exists $transcription_index{$word}) {
                    $found_in_transcription = 1;
                    last;
                }
            }

            # Solo marcar como error si la similitud es muy baja Y no está en transcripción
            if ($similarity < 0 && !$found_in_transcription) {
                push @real_errors, {
                    start_time => $segment->{start_time},
                    end_time => $segment->{end_time},
                    ipu_word => $ipu_word,
                    error_type => 'audio_only'
                };
            }
        }
    }

    return {
        errors => \@real_errors,
        transcription_tier => \@transcription_tier_data
    };
}

sub concatenate_empty_ipus {
    my ($errors) = @_;

    return $errors unless @$errors;

    my @concatenated;
    my $current_group = [];

    foreach my $error (@$errors) {
        if (@$current_group == 0) {
            push @$current_group, $error;
        }
        elsif ($error->{start_time} - $current_group->[-1]->{end_time} < 0.1) {
            # Concatenar errores consecutivos (menos de 0.1s de separación)
            push @$current_group, $error;
        }
        else {
            # Procesar grupo actual
            if (@$current_group == 1) {
                push @concatenated, $current_group->[0];
            } else {
                # Concatenar múltiples errores
                my @words = map { $_->{ipu_word} } @$current_group;
                push @concatenated, {
                    start_time => $current_group->[0]->{start_time},
                    end_time => $current_group->[-1]->{end_time},
                    ipu_word => join(' ', @words),
                    error_type => 'concatenated_audio_only'
                };
            }

            # Iniciar nuevo grupo
            $current_group = [$error];
        }
    }

    # Procesar último grupo
    if (@$current_group == 1) {
        push @concatenated, $current_group->[0];
    } elsif (@$current_group > 1) {
        my @words = map { $_->{ipu_word} } @$current_group;
        push @concatenated, {
            start_time => $current_group->[0]->{start_time},
            end_time => $current_group->[-1]->{end_time},
            ipu_word => join(' ', @words),
            error_type => 'concatenated_audio_only'
        };
    }

    return \@concatenated;
}

#############################################################################
# CREACIÓN DE TEXTGRID
#############################################################################

sub create_enhanced_textgrid_tiers {
    my ($textgrid, $transcription_tier_data, $error_segments) = @_;

    # Tier de transcripción HTML alineada
    my $html_transc_tier = new NodeChain('TranscHTML');
    foreach my $segment (@$transcription_tier_data) {
        next unless $segment->{text} && $segment->{text} ne '';

        my $range = new Range($segment->{start_time}, $segment->{end_time});
        my $node = new Node($segment->{text}, $range);
        $html_transc_tier->addNodes($node);
    }
    $textgrid->addTier($html_transc_tier);

    # Tier de errores (solo palabras que NO están en la transcripción)
    my $errors_tier = new NodeChain('ErrorsOnly');
    foreach my $error (@$error_segments) {
        my $ipu_text = $error->{ipu_word};
        my $contains_num = 0;
        if ($ipu_text =~ /<NUM>/) {
            $contains_num = 1;
        } else {
            my @words = split(/\s+/, lc($ipu_text));
            foreach my $word (@words) {
                if ($word =~ /^\d+([.,]\d+)*$/ || is_number_word($word)) {
                    $contains_num = 1;
                    last;
                }
            }
        }
        next if $contains_num;

        my $error_text = "ERROR: '" . $ipu_text . "'";
        my $range = new Range($error->{start_time}, $error->{end_time});
        my $node = new Node($error_text, $range);
        $errors_tier->addNodes($node);
    }
    $textgrid->addTier($errors_tier);
}

#############################################################################
# MODELADO HMM
#############################################################################

sub preprocess_for_hmm {
    my ($align_file) = @_;

    my $align_data = load_align_file($align_file);
    return unless $align_data->{asr_words} && $align_data->{reference_words};

    my $alignment = align_word_sequences($align_data->{asr_words}, $align_data->{reference_words});

    my @observations;
    my @labels;

    foreach my $item (@$alignment) {
        push @observations, create_observation($item);
        push @labels, classify_alignment_error($item);
    }

    return {
        observations => \@observations,
        labels => \@labels,
        alignment => $alignment
    };
}

sub create_observation {
    my ($alignment_item) = @_;

    my $asr_word = $alignment_item->{word1} || '';
    my $ref_word = $alignment_item->{word2} || '';

    my @features;
    push @features, abs(length($asr_word) - length($ref_word));

    if ($asr_word && $ref_word) {
        my $distance = levenshtein_distance($asr_word, $ref_word);
        my $max_len = max(length($asr_word), length($ref_word));
        push @features, $max_len > 0 ? ($distance / $max_len) : 0;
    } else {
        push @features, 1.0;
    }

    push @features, $asr_word ? 1 : 0;
    push @features, $ref_word ? 1 : 0;

    return join(',', @features);
}

sub classify_alignment_error {
    my ($alignment_item) = @_;

    my $operation = $alignment_item->{operation};
    my $word1 = $alignment_item->{word1} || '';
    my $word2 = $alignment_item->{word2} || '';

    if (($word1 =~ /^\d+([.,]\d+)*$/ || $word1 eq '<NUM>') &&
        ($word2 =~ /^\d+([.,]\d+)*$/ || $word2 eq '<NUM>')) {
        return '<M>';
    }

    # Verificar guiones - deben ser Delete
    if ($word1 =~ /^-+$/ || $word2 =~ /^-+$/) {
        return '<D>';
    }

    return '<M>' if $word1 eq $word2;
    return '<D>' if $operation eq 'delete';
    return '<I>' if $operation eq 'insert';

    if ($operation eq 'match' && $word1 ne $word2) {
        my $distance = levenshtein_distance($word1, $word2);
        my $max_len = max(length($word1), length($word2));

        return '<M>' if $max_len == 0;

        my $similarity = 1 - ($distance / $max_len);

        if ($similarity >= 0.8) { return '<A1>'; }
        elsif ($similarity >= 0.6) { return '<A2>'; }
        elsif ($similarity >= 0.4) { return '<A3>'; }
        elsif ($similarity >= 0.2) { return '<A4>'; }
        elsif ($similarity > 0) { return '<A5>'; }
        else { return '<S>'; }
    }

    return '<S>';
}

sub train_hmm {
    my ($preprocessed_data_list) = @_;

    my %initial_counts;
    my %transition_counts;
    my %emission_counts;
    my %state_counts;
    my %observation_counts;

    foreach my $data (@$preprocessed_data_list) {
        my $observations = $data->{observations};
        my $labels = $data->{labels};

        next unless @$observations == @$labels;

        my @states = map { $LABEL_TO_STATE{$_} || '<SUS>' } @$labels;

        if (@states > 0) {
            $initial_counts{$states[0]}++;
        }

        for my $i (0..$#states) {
            my $state = $states[$i];
            $state_counts{$state}++;
            $emission_counts{$state}{$observations->[$i]}++;
            $observation_counts{$observations->[$i]}++;

            if ($i < $#states) {
                $transition_counts{$state}{$states[$i+1]}++;
            }
        }
    }

    # Calcular probabilidades
    my %initial_probs;
    my %transition_probs;
    my %emission_probs;
    my $smoothing = 1e-10;

    my $total_initial = sum(values %initial_counts) || 1;
    foreach my $state (@HIDDEN_STATES) {
        $initial_probs{$state} = safe_log(($initial_counts{$state} || 0 + $smoothing) /
                                         ($total_initial + @HIDDEN_STATES * $smoothing));
    }

    foreach my $from_state (@HIDDEN_STATES) {
        my $total_from = sum(values %{$transition_counts{$from_state}}) || 0;
        foreach my $to_state (@HIDDEN_STATES) {
            $transition_probs{$from_state}{$to_state} =
                safe_log(($transition_counts{$from_state}{$to_state} || 0 + $smoothing) /
                        ($total_from + @HIDDEN_STATES * $smoothing));
        }
    }

    foreach my $state (@HIDDEN_STATES) {
        my $total_emissions = $state_counts{$state} || 0;
        foreach my $obs (keys %observation_counts) {
            $emission_probs{$state}{$obs} =
                safe_log(($emission_counts{$state}{$obs} || 0 + $smoothing) /
                        ($total_emissions + scalar(keys %observation_counts) * $smoothing));
        }
    }


    return {
        initial_probs => \%initial_probs,
        transition_probs => \%transition_probs,
        emission_probs => \%emission_probs,
        hidden_states => \@HIDDEN_STATES,
        label_to_state => \%LABEL_TO_STATE,
    };
}

sub viterbi_decode {
    my ($model, $observations) = @_;

    my $n_obs = scalar(@$observations);
    my @states = @{$model->{hidden_states}};
    my $n_states = scalar(@states);

    return [] if $n_obs == 0;


    my @viterbi;
    my @path;

    # Inicializar primer paso
    for my $s (0..$n_states-1) {
        my $state = $states[$s];
        my $emission_prob = $model->{emission_probs}{$state}{$observations->[0]} || safe_log(1e-10);
        $viterbi[0][$s] = $model->{initial_probs}{$state} + $emission_prob;
        $path[0][$s] = -1;
    }

    # Pasos hacia adelante
    for my $t (1..$n_obs-1) {
        for my $s (0..$n_states-1) {
            my $state = $states[$s];
            my $emission_prob = $model->{emission_probs}{$state}{$observations->[$t]} || safe_log(1e-10);

            my $best_prob = -999999;
            my $best_prev = -1;

            for my $prev_s (0..$n_states-1) {
                my $prev_state = $states[$prev_s];
                my $trans_prob = $model->{transition_probs}{$prev_state}{$state} || safe_log(1e-10);
                my $prob = $viterbi[$t-1][$prev_s] + $trans_prob + $emission_prob;

                if ($prob > $best_prob) {
                    $best_prob = $prob;
                    $best_prev = $prev_s;
                }
            }

            $viterbi[$t][$s] = $best_prob;
            $path[$t][$s] = $best_prev;
        }
    }

    my $best_final_prob = -999999;
    my $best_final_state = -1;

    for my $s (0..$n_states-1) {
        if ($viterbi[$n_obs-1][$s] > $best_final_prob) {
            $best_final_prob = $viterbi[$n_obs-1][$s];
            $best_final_state = $s;
        }
    }

    my @best_path;
    my $current_state = $best_final_state;

    for my $t (reverse 0..$n_obs-1) {
        $best_path[$t] = $states[$current_state];
        $current_state = $path[$t][$current_state] if $t > 0;
    }

    return \@best_path;
}

#############################################################################
# FUNCIONES PRINCIPALES
#############################################################################

sub process_dataset {
    my ($base_dir, $dataset_id) = @_;

    print "Procesando $dataset_id\n";

    my $dataset_dir = "$base_dir/$dataset_id";
    my $textgrid_file = "$dataset_dir/$dataset_id.TextGrid";
    my $align_file = "$base_dir/$dataset_id.align";

    unless (-f $textgrid_file && -f $align_file) {
        warn "Archivos faltantes para $dataset_id\n";
        return;
    }

    # Cargar datos
    my $textgrid = load_textgrid($textgrid_file);
    my $ipu_segments = extract_ipu_segments($textgrid);
    my $html_transcriptions = load_html_transcriptions($dataset_dir);

    # Alinear texto
    my $timed_segments = align_transcriptions_with_ipu($html_transcriptions, $ipu_segments);

    # Obtener texto completo de transcripción para detección de errores
    my $full_transcription = join(' ', map { $_->{text} } @$html_transcriptions);

    # Detectar errores reales (palabras que aparecen solo en el audio)
    my $detection_results = detect_real_errors($timed_segments, $full_transcription);

    # Concatenar IPUs vacíos/errores consecutivos
    my $concatenated_errors = concatenate_empty_ipus($detection_results->{errors});

    # Filtrar números de la lista final de errores para JSON
    my @filtered_errors;
    foreach my $error (@$concatenated_errors) {
        my $ipu_text = $error->{ipu_word};
        my $contains_num = 0;
        if ($ipu_text =~ /<NUM>/) {
            $contains_num = 1;
        } else {
            my @words = split(/\s+/, lc($ipu_text));
            foreach my $word (@words) {
                if ($word =~ /^\d+([.,]\d+)*$/ || is_number_word($word)) {
                    $contains_num = 1;
                    last;
                }
            }
        }
        push @filtered_errors, $error unless $contains_num;
    }

    # Crear tiers mejorados en TextGrid
    create_enhanced_textgrid_tiers($textgrid, $detection_results->{transcription_tier}, $concatenated_errors);

    # Guardar resultado
    my $output_file = "$dataset_dir/${dataset_id}_processed.TextGrid";
    $textgrid->flash($output_file);

    # Guardar clasificación mejorada
    my $classification_file = "results/${dataset_id}_classification.json";
    my $results = {
        timestamp => scalar(localtime),
        total_real_errors => scalar(@filtered_errors),
        real_errors => \@filtered_errors,
        transcription_segments => scalar(@{$detection_results->{transcription_tier}}),
        analysis_type => 'audio_only_errors'
    };

    my $json = JSON->new->utf8->pretty;
    open(my $fh, '>:encoding(UTF-8)', $classification_file) or die $!;
    print $fh $json->encode($results);
    close($fh);

    print "Dataset procesado\n";
    print "TextGrid: $output_file\n";

    return {
        dataset_id => $dataset_id,
        timed_segments => $timed_segments,
        real_errors => \@filtered_errors
    };
}

sub train_system {
    print "Entrenando sistema\n";
    my @training_results;
    opendir(my $dh, $CONFIG->{training_dir}) or die "No se puede abrir directorio de entrenamiento: $!";
    my @datasets = grep { -d "$CONFIG->{training_dir}/$_" && $_ !~ /^\./ && $_ =~ /^\d+$/ } readdir($dh);
    closedir($dh);
    foreach my $dataset (@datasets) {
        my $result = process_dataset($CONFIG->{training_dir}, $dataset);
        push @training_results, $result if $result;
    }

    # Preprocesar para HMM
    print "\nPreparando datos para HMM...\n";
    my @hmm_data;
    opendir($dh, $CONFIG->{training_dir}) or die $!;
    my @align_files = grep { /\.align$/ } readdir($dh);
    closedir($dh);

    foreach my $align_file (@align_files) {
        my $preprocessed = preprocess_for_hmm("$CONFIG->{training_dir}/$align_file");
        push @hmm_data, $preprocessed if $preprocessed;
    }

    # Entrenar HMM
    my $model = train_hmm(\@hmm_data);

    # Guardar modelo
    my $json = JSON->new->utf8->pretty;
    open(my $fh, '>:encoding(UTF-8)', $CONFIG->{model_file}) or die $!;
    print $fh $json->encode($model);
    close($fh);

    print "\n✓ ENTRENAMIENTO COMPLETADO\n";
    print "Modelo guardado: $CONFIG->{model_file}\n";
}

sub validate_system {
    print "Validando sistema\n";

    unless (-f $CONFIG->{model_file}) {
        die "Modelo no encontrado. Ejecute primero: perl asr_system.pl train\n";
    }
    print "Cargando modelo HMM...\n";
    open(my $fh, '<:encoding(UTF-8)', $CONFIG->{model_file}) or die $!;
    my $content = do { local $/; <$fh> };
    close($fh);
    my $model = JSON->new->utf8->decode($content);
    opendir(my $dh, $CONFIG->{validation_dir}) or die "No se puede abrir directorio de validación: $!";
    my @datasets = grep { -d "$CONFIG->{validation_dir}/$_" && $_ !~ /^\./ && $_ =~ /^\d+$/ } readdir($dh);
    closedir($dh);
    my @validation_results;
    foreach my $dataset (@datasets) {
        print "Validando $dataset\n";

        # Procesar con sistema de alineación
        my $result = process_dataset($CONFIG->{validation_dir}, $dataset);
        next unless $result;

        # Usar HMM para predicción
        my $align_file = "$CONFIG->{validation_dir}/$dataset.align";
        my $preprocessed = preprocess_for_hmm($align_file);

        if ($preprocessed) {
            my $predicted_states = viterbi_decode($model, $preprocessed->{observations});

            push @validation_results, {
                dataset_id => $dataset,
                predicted_states => $predicted_states,
                actual_labels => $preprocessed->{labels}
            };
        }
        push @validation_results, $result;
    }

    # Guardar resultados de validación
    my $validation_file = 'results/validation_results.json';
    my $json = JSON->new->utf8->pretty;
    open($fh, '>:encoding(UTF-8)', $validation_file) or die $!;
    print $fh $json->encode({
        timestamp => scalar(localtime),
        results => \@validation_results
    });
    close($fh);

    print "Validacion completada\n";
    print "Resultados: $validation_file\n";
}

#############################################################################
# INTERFAZ DE LÍNEA DE COMANDOS
#############################################################################

sub show_usage {
    print "Sistema ASR de Alineación y Clasificación de Errores\n\n";
    print "Uso: perl asr_system.pl [comando] [opciones]\n\n";
    print "Comandos:\n";
    print "  train              Entrenar el sistema con datos de entrenamiento\n";
    print "  validate           Validar con datos de prueba (requiere modelo entrenado)\n";
    print "  process DIR        Procesar directorio específico\n";
    print "Ejemplos:\n";
    print "  perl asr_system.pl train\n";
    print "  perl asr_system.pl validate\n";
    print "  perl asr_system.pl process data/training\n\n";
}

sub main {
    my $command = $ARGV[0] || 'help';
    if ($command eq 'train') {
        train_system();
    } elsif ($command eq 'validate') {
        validate_system();
    } elsif ($command eq 'process') {
        my $dir = $ARGV[1] or die "Especifique directorio para procesar\n";
        die "Directorio no encontrado: $dir\n" unless -d $dir;
        opendir(my $dh, $dir) or die $!;
        my @datasets = grep { -d "$dir/$_" && $_ !~ /^\./ && $_ =~ /^\d+$/ } readdir($dh);
        closedir($dh);
        foreach my $dataset (@datasets) {
            process_dataset($dir, $dataset);
        }
    } elsif ($command eq 'help') {
        show_usage();
    } else {
        print "Comando desconocido: $command\n\n";
        show_usage();
        exit 1;
    }
}

main();
