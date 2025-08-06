# Documentación del Sistema ASR - Alineación y Clasificación de Errores
# Nombre: Muzo Miguel

## Descripción General

Este sistema implementa un algoritmo avanzado de alineación automática entre transcripciones HTML y audio segmentado, con detección inteligente de errores reales. El objetivo principal es identificar palabras que aparecen únicamente en el audio pero no en la transcripción de referencia, siguiendo los criterios de la Parte 1b del proyecto.


## Uso del Sistema

### 1. Entrenamiento
```bash
perl asr_system.pl train
```
**Salida:**
- `data/training/*/202003301830_processed.TextGrid`
- `data/training/202003301830_classification.json`
- `modelo_hmm.json`

### 2. Validación
```bash
perl asr_system.pl validate
```
**Salida:**
- `data/validation/*/202003311300_processed.TextGrid`
- `data/validation/202003311300_classification.json`
- `validation_results.json`

### 3. Procesar directorio específico
```bash
perl asr_system.pl process data/training
perl asr_system.pl process data/validation
```

### 4. Ayuda
```bash
perl asr_system.pl help
```


## Arquitectura del Sistema

### Componentes Principales

1. **Normalización de Texto**
2. **Carga y Procesamiento de Datos**
3. **Algoritmo de Alineación**
4. **Detección Inteligente de Errores**
5. **Generación de TextGrid Mejorado**
6. **Modelado HMM**

---

## Funciones Principales

### 1. Normalización de Texto

#### `normalize_text($text)`

**Propósito**: Normaliza texto para comparación consistente entre transcripciones HTML y audio IPU.

**Proceso detallado**:
1. **Procesamiento Unicode**: Convierte códigos Unicode (`\u00f3` → `ó`)
2. **Limpieza HTML**: Elimina etiquetas y entidades HTML
3. **Normalización de acentos**: `áéíóú` → `aeiou`
4. **Conversión de números**: Dígitos → `<NUM>`
5. **Normalización de espacios**: Múltiples espacios → espacio único

**Algoritmo**:
```perl
# Paso 1: Códigos Unicode
$text =~ s/\\u00f3/ó/g;  # ó
$text =~ s/\\u00e1/á/g;  # á
# ... más caracteres

# Paso 2: Normalización de acentos
$text =~ s/[áàâäãå]/a/g;
$text =~ s/[éèêë]/e/g;
# ... más acentos

# Paso 3: Números a tokens
$text =~ s/\b\d+([.,]\d+)*\b/<NUM>/g;
```

**Entrada**: `"Japón amplía la prohibición por 2008."`
**Salida**: `"japon amplia la prohibicion por <NUM>"`

---

### 2. Carga y Procesamiento de Datos

#### `extract_text_from_html($file_path)`

**Propósito**: Extrae contenido textual de archivos HTML usando múltiples estrategias.

**Estrategias de extracción**:
1. **JSON-LD**: Busca `"articleBody"` en estructuras JSON
2. **Párrafos HTML**: Extrae contenido de etiquetas `<p>`
3. **Meta descripción**: Fallback a meta description

**Algoritmo**:
```perl
# Estrategia 1: JSON-LD
if ($content =~ /"articleBody":\s*"([^"]+)"/s) {
    return process_json_content($1);
}

# Estrategia 2: Párrafos
while ($content =~ /<p[^>]*>(.*?)<\/p>/gis) {
    push @paragraphs, clean_html($1);
}

# Estrategia 3: Meta descripción
if ($content =~ /<meta\s+name="description"\s+content="([^"]+)"/i) {
    return $1;
}
```

#### `extract_ipu_segments($textgrid)`

**Propósito**: Extrae segmentos IPU (Inter-Pausal Units) del archivo TextGrid.

**Proceso**:
1. Busca tier IPU en el TextGrid
2. Filtra intervalos vacíos o con marcadores especiales
3. Normaliza texto de cada segmento
4. Calcula tiempos de inicio y fin

**Criterios de filtrado**:
- Excluye textos vacíos: `""`
- Excluye marcadores: `#`, `_`, `@`
- Excluye solo espacios: `/^[\s]*$/`

---

### 3. Algoritmo de Alineación

#### `align_transcriptions_with_ipu($transcriptions, $ipu_segments)`

**Propósito**: Alinea transcripciones HTML con segmentos de audio IPU.

**Proceso general**:
1. Concatena texto completo de transcripciones
2. Concatena texto completo de IPU
3. Ejecuta alineación palabra por palabra
4. Mapea alineación a tiempos específicos

#### `align_word_sequences($seq1, $seq2)`

**Propósito**: Implementa algoritmo de programación dinámica para alineación óptima.

**Algoritmo (Needleman-Wunsch modificado)**:

```perl
# Matriz de programación dinámica
for my $i (1..$len1) {
    for my $j (1..$len2) {
        my $similarity = calculate_word_similarity($seq1->[$i-1], $seq2->[$j-1]);

        my $match_score = $dp[$i-1][$j-1] + $similarity;
        my $insert_score = $dp[$i][$j-1] - 2;      # Penalización inserción
        my $delete_score = $dp[$i-1][$j] - 2;      # Penalización eliminación

        # Seleccionar mejor opción
        $dp[$i][$j] = max($match_score, $insert_score, $delete_score);
    }
}
```

**Operaciones de alineación**:
- **Match**: Palabra en transcripción ↔ palabra en audio
- **Insert**: Palabra solo en audio (candidato a error)
- **Delete**: Palabra solo en transcripción

#### `calculate_word_similarity($word1, $word2)`

**Propósito**: Calcula similitud entre dos palabras usando distancia de Levenshtein.

**Puntuación**:
- **Coincidencia exacta**: +5 puntos
- **Alta similitud** (>80%): +3 puntos
- **Media similitud** (60-80%): +2 puntos
- **Baja similitud** (40-60%): +1 punto
- **Muy baja similitud** (<40%): -1 punto
- **Números vs `<NUM>`**: +4 puntos

**Fórmula**:
```perl
my $distance = levenshtein_distance($word1, $word2);
my $similarity = 1 - ($distance / max(length($word1), length($word2)));
```

---

### 4. Detección Inteligente de Errores

#### `detect_real_errors($timed_segments, $transcription_text)`

**Propósito**: Identifica errores reales eliminando falsos positivos mediante verificación contra índice de transcripción.

**Algoritmo mejorado**:

```perl
# Crear índice de palabras de transcripción
my @transcription_words = split(/\s+/, normalize_text($transcription_text));
my %transcription_index;
foreach my $word (@transcription_words) {
    $transcription_index{$word} = 1 if $word ne '';
}

# Verificar cada segmento
foreach my $segment (@$timed_segments) {
    if ($operation eq 'insert' && $ipu_word) {
        my @ipu_words = split(/\s+/, normalize_text($ipu_word));
        my $found_in_transcription = 0;

        # Verificar cada palabra del segmento IPU
        foreach my $word (@ipu_words) {
            if (exists $transcription_index{$word}) {
                $found_in_transcription = 1;
                last;
            }
        }

        # Solo marcar como error si NINGUNA palabra está en transcripción
        if (!$found_in_transcription) {
            push @real_errors, { ... };
        }
    }
}
```

**Criterios de error**:
1. **Operación "insert"**: Palabra marcada por alineación como solo en audio
2. **Verificación de índice**: Ninguna palabra del segmento IPU existe en transcripción
3. **Filtro de tokens**: Excluye `<NUM>` y palabras vacías

**Tipos de errores detectados**:
- `audio_only`: Palabra individual no en transcripción
- `concatenated_audio_only`: Múltiples palabras consecutivas agrupadas

---

### 5. Consolidación de Errores

#### `concatenate_empty_ipus($errors)`

**Propósito**: Agrupa errores consecutivos en un solo IPU para simplificar estructura.

**Algoritmo**:
```perl
foreach my $error (@$errors) {
    if (tiempo_entre_errores < 0.1_segundos) {
        # Agregar a grupo actual
        push @current_group, $error;
    } else {
        # Procesar grupo anterior y crear nuevo
        if (@current_group > 1) {
            # Concatenar múltiples errores
            my $concatenated = {
                ipu_word => join(' ', map { $_->{ipu_word} } @current_group),
                error_type => 'concatenated_audio_only'
            };
        }
    }
}
```

**Beneficios**:
- Reduce fragmentación de errores
- Agrupa números complejos: "ciento ochenta y seis"
- Simplifica análisis posterior

---

### 6. Generación de TextGrid Mejorado

#### `create_enhanced_textgrid_tiers($textgrid, $transcription_tier_data, $error_segments)`

**Propósito**: Crea dos nuevos tiers según especificaciones del proyecto.

**Tiers generados**:

1. **TranscHTML**:
   - Contiene transcripción alineada temporalmente
   - Refleja palabras de la transcripción HTML
   - Permite validación temporal

2. **ErrorsOnly**:
   - Contiene únicamente errores reales detectados
   - Formato: `"ERROR: 'palabra'"`
   - Tiempos precisos del audio original

**Estructura**:
```perl
# Tier TranscHTML
foreach my $segment (@$transcription_tier_data) {
    my $node = new Node($segment->{text},
                       new Range($segment->{start_time}, $segment->{end_time}));
    $html_tier->addNodes($node);
}

# Tier ErrorsOnly
foreach my $error (@$error_segments) {
    my $error_text = "ERROR: '" . $error->{ipu_word} . "'";
    my $node = new Node($error_text,
                       new Range($error->{start_time}, $error->{end_time}));
    $errors_tier->addNodes($node);
}
```

---

### 7. Modelado HMM (Hidden Markov Model)

#### Estados del modelo:
- `<MAT>`: Match (coincidencia)
- `<DEL>`: Deletion (eliminación)
- `<INS>`: Insertion (inserción)
- `<TRA>`: Transposition (transposición)
- `<SUS>`: Substitution (sustitución)

#### `train_hmm($preprocessed_data_list)`

**Propósito**: Entrena modelo HMM para clasificación automática de errores.

**Proceso**:
1. **Conteo de frecuencias**: Estados iniciales, transiciones, emisiones
2. **Smoothing**: Evita probabilidades cero con factor 1e-10
3. **Conversión logarítmica**: Previene underflow numérico

**Fórmulas**:
```perl
# Probabilidades iniciales
P(estado_inicial) = (count + smoothing) / (total + num_estados * smoothing)

# Probabilidades de transición
P(estado_j | estado_i) = (count_ij + smoothing) / (total_i + num_estados * smoothing)

# Probabilidades de emisión
P(observación | estado) = (count + smoothing) / (total_estado + num_obs * smoothing)
```

#### `viterbi_decode($model, $observations)`

**Propósito**: Encuentra secuencia de estados más probable usando algoritmo de Viterbi.

**Algoritmo**:
```perl
# Inicialización
for my $s (0..$n_states-1) {
    $viterbi[0][$s] = $initial_prob[$s] + $emission_prob[$s][$obs[0]];
}

# Recursión hacia adelante
for my $t (1..$n_obs-1) {
    for my $s (0..$n_states-1) {
        my $best_prob = max_over_prev_states(
            $viterbi[$t-1][$prev_s] + $transition_prob[$prev_s][$s]
        ) + $emission_prob[$s][$obs[$t]];
        $viterbi[$t][$s] = $best_prob;
    }
}

# Backtracking para recuperar mejor camino
```

---

## Flujo de Ejecución

### Modo Training

1. **Carga de datos**:
   - TextGrid files → IPU segments
   - HTML files → transcripciones normalizadas
   - Align files → datos de referencia

2. **Procesamiento**:
   - Alineación transcripción ↔ IPU
   - Detección de errores reales
   - Consolidación de errores consecutivos

3. **Generación de salidas**:
   - TextGrid mejorado con tiers TranscHTML y ErrorsOnly
   - JSON con clasificación de errores
   - Modelo HMM entrenado

### Modo Validation

1. **Carga de modelo HMM entrenado**
2. **Procesamiento de datos de validación**
3. **Predicción usando Viterbi**
4. **Evaluación de resultados**

---

### Resultados
- **Precisión inicial**: 53.2% (22 falsos positivos de 47 errores)
- **Precisión final**: 100.0% (0 falsos positivos de 50 errores)
- **Tipos de errores válidos detectados**:
  - Números específicos del audio
  - Palabras en inglés
  - Fragmentos de palabras
  - Audio introductorio/conclusivo
  - Pausas y descansos

---

## Archivos de Salida

### TextGrid Mejorado
```
Tier 1: 'Noticias' (original)
Tier 2: 'IPU' (original)
Tier 3: 'TranscHTML' (nuevo - transcripción alineada)
Tier 4: 'ErrorsOnly' (nuevo - solo errores reales)
```

### JSON de Clasificación
```json
{
  "analysis_type": "audio_only_errors",
  "total_real_errors": 50,
  "transcription_segments": 1968,
  "real_errors": [
    {
      "start_time": 0,
      "end_time": 40.585814,
      "ipu_word": "introduccion",
      "error_type": "audio_only"
    }
  ]
}
```
