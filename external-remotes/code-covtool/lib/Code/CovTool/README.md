# Code::CovTool — подмодули

**Версия:** v0.0.7

---

## CoverageData

# NAME

Code::CovTool::CoverageData - операции над данными покрытия (merge, export, zero)

# SYNOPSIS

    my $merged = Code::CovTool::CoverageData::merge_datasets( [ $data1, $data2 ] );
    my $lcov_str = Code::CovTool::CoverageData::to_lcov( $summary_hash );
    Code::CovTool::CoverageData::zero_file_data( $file_data_ref );

# DESCRIPTION

Пакет с функциями для работы со структурой данных покрытия:
объединение наборов, сериализация в LCOV, обнуление счётчиков.
Используется в Code::CovTool для объединения данных, экспорта в LCOV и обнуления при remove.

# FUNCTIONS

## merge\_datasets

    my $merged = Code::CovTool::CoverageData::merge_datasets( \@datasets );

Объединяет несколько наборов данных покрытия в один: для каждого файла суммирует
счётчики строк (DA) и функций (FNDA), объединяет check и метаданные функций.
При несовпадении контрольных сумм завершает программу.

- **\\@datasets** — массив ссылок на хэши (каждый хэш: путь к файлу => { sum, func, check, sumfnc })

Возвращает ссылку на хэш объединённых данных.

## to\_lcov

    my $str = Code::CovTool::CoverageData::to_lcov( $summary );

Формирует строку в формате LCOV по хэшу данных покрытия (SF, DA, FN, FNDA, FNF, FNH, LH, LF, end\_of\_record).

- **$summary** — хэш данных покрытия (как у ["merge\_datasets"](#merge_datasets))

Возвращает строку, пригодную для genhtml и аналогичных утилит.

## zero\_file\_data

    Code::CovTool::CoverageData::zero_file_data( $file_data );

Обнуляет счётчики строк и функций в одной записи покрытия (мутирует переданный хэш).
Используется в методе remove из Code::CovTool.

- **$file\_data** — ссылка на хэш { sum => {...}, sumfnc => {...} } (и др. ключи без изменений)

Ничего не возвращает.


## PathFilter

# NAME

Code::CovTool::PathFilter - валидация путей и фильтрация ключей покрытия по путям

# SYNOPSIS

    my $filter = Code::CovTool::PathFilter->new( sources => $cov_tool_sources );
    my $path_info = $filter->validate_path( 'src/backend/utils' );
    my $path_infos = $filter->normalize_and_validate_files( files => [ 'src/a.c', 'src/' ] );
    my @keys = $filter->coverage_keys_for_paths( $path_infos, $summary_hash );

# DESCRIPTION

Проверяет пути относительно дерева исходников (Code::CovTool::Sources),
нормализует аргументы clip/remove (строка или files => \[\]),
возвращает список ключей покрытия, соответствующих заданным путям (файл/директория).

# CONSTRUCTOR

## new

    my $filter = Code::CovTool::PathFilter->new( sources => $cov_tool_sources );

Создаёт экземпляр, привязанный к дереву исходников.

- **sources** (обязательный)

    Объект Code::CovTool::Sources.

# METHODS

## validate\_path

    my $path_info = $filter->validate_path( 'src/backend/utils' );

Нормализует путь, проверяет, что он существует внутри дерева исходников.
При ошибке завершает программу.

- **$path** — путь к файлу или директории (относительный или абсолютный)

Возвращает хэш: `rel_path`, `full_path`, `is_same_as_src_dir`; для корня src\_dir
только `is_same_as_src_dir => 1`.

## normalize\_and\_validate\_files

    my $path_infos = $filter->normalize_and_validate_files( files => [ 'src/a.c', 'src/' ] );
    my $path_infos = $filter->normalize_and_validate_files( 'src/single.c' );
    my $path_infos = $filter->normalize_and_validate_files( $sources_obj );
    my $path_infos = $filter->normalize_and_validate_files( { files => [ 'src/a.c' ] } );
    my $path_infos = $filter->normalize_and_validate_files(
      { allow_empty_files => 1, warn_on_empty_files => 1 },
      files => []
    );

Принимает один путь (строка), `files => \@paths` или hashref-конфигурацию с ключом `files`.
Для каждого пути вызывает ["validate\_path"](#validate_path).

В списке путей также допускается объект `Code::CovTool::Sources`: в этом случае
используется его `src_dir` (удобно для явного указания корня исходников).
Также допускается объект `Path::Tiny` — он приводится к строковому пути.

Дополнительные ключи в hashref-конфигурации допускаются и пока игнорируются.
Это сделано для совместимости внешнего API (например, когда hashref формируется
общим кодом), но сам `PathFilter` обрабатывает только фильтрацию по путям.

По умолчанию пустой `files => []` не допускается (ошибка). Если передана опция
`allow_empty_files => 1`, возвращается пустой список path\_info; при
`warn_on_empty_files => 1` дополнительно выводится warning.

Явные дубликаты (один и тот же относительный
путь) и пути, избыточные относительно другого элемента списка (папка уже покрывает файл),
из входной последовательности в результат не попадают — предупреждение на каждый отброшенный
элемент. Переданный массив `files` не изменяется.

Возвращает ссылку на массив хэшей (как у ["validate\_path"](#validate_path) плюс `rel_path_normalized`
и `input_path`) — без дубликатов по `rel_path_normalized` и без избыточных вложенных путей.

## coverage\_keys\_matching\_path\_info

    my $keys = $filter->coverage_keys_matching_path_info( $path_info, $summary );

По одному path\_info и хэшу покрытия возвращает ключи файлов, подходящие под путь
(файл — точное совпадение/суффикс, директория — префикс). Если путь совпадает с
корнем исходников — все ключи.

- **$path\_info** — хэш от ["validate\_path"](#validate_path)
- **$summary** — хэш данных покрытия (ключи — пути к файлам)

Возвращает ссылку на массив ключей (путей).

## coverage\_keys\_for\_paths

    my @keys = $filter->coverage_keys_for_paths( $path_infos, $summary );

Объединяет результаты ["coverage\_keys\_matching\_path\_info"](#coverage_keys_matching_path_info) по всем path\_info
(объединение множеств ключей без дубликатов).

- **$path\_infos** — ссылка на массив path\_info (результат ["normalize\_and\_validate\_files"](#normalize_and_validate_files))
- **$summary** — хэш данных покрытия

Возвращает список ключей (путей к файлам в покрытии).


## PathResolver

# NAME

Code::CovTool::PathResolver - перебазирование путей покрытия между деревьями исходников

# SYNOPSIS

    my $resolver = Code::CovTool::PathResolver->new(
      old_sources => $old_cov_tool_sources,
      new_sources => $new_cov_tool_sources,
    );
    my $rebased_data = $resolver->rebase_coverage_data( $parsed_coverage );

# DESCRIPTION

Проверяет совместимость двух деревьев исходников (одинаковые файлы по относительным путям),
сравнивает размеры и содержимое файлов, переводит данные покрытия с путей старого дерева
на пути нового дерева. Используется в Code::CovTool::rebase.


## Sources

# NAME

Code::CovTool::Sources - работа с каталогом исходных файлов

# SYNOPSIS

    use Path::Tiny qw( path );

    my $sources = Code::CovTool::Sources->new( src_dir => '/path/to/src' );
    my $sources2 = Code::CovTool::Sources->new( src_dir => path('/path/to/src') );
    $sources->check_path( $src_path, $line_num );
    my %files = $sources->get_file_list;
    my $rel_path = $sources->get_relative_path( $full_path );

# DESCRIPTION

Представляет дерево исходников: проверяет существование и расположение файлов относительно
src\_dir, возвращает списки файлов и относительные пути. Используется в Code::CovTool, Code::CovTool::PathResolver,
Code::CovTool::PathFilter, Code::CovTool::Tracefile и в тестовом Helper.

# CONSTRUCTOR

## new

    my $sources = Code::CovTool::Sources->new( src_dir => '/path/to/src' );

Создаёт экземпляр, привязанный к каталогу исходников.

- **src\_dir** (обязательный)

    Путь к существующей директории с исходным кодом (строка или `Path::Tiny`).

- **url** (опционально)

    URL репозитория для ["get\_sources"](#get_sources).

# METHODS

## check\_path

    $sources->check_path( $src_path, $line_num );

Проверяет путь из LCOV: файл должен существовать, быть обычным файлом и находиться внутри
src\_dir. При ошибке завершает программу с сообщением (указывается номер строки в LCOV).

- **$src\_path** — путь к исходнику (как в LCOV, может быть относительным или абсолютным)
- **$line\_num** — номер строки в LCOV (для сообщений об ошибках)

Возвращает 1 при успехе.

## get\_file\_list

    my %files = $sources->get_file_list;

Возвращает хэш: ключ — относительный путь от src\_dir, значение — полный путь к файлу.
Включаются только файлы (директории не входят).

## get\_relative\_path

    my $rel_path = $sources->get_relative_path( $full_path );

Преобразует полный путь в относительный к src\_dir. Завершает программу, если путь
находится вне src\_dir.

- **$full\_path** — абсолютный путь к файлу

Возвращает строку относительного пути.

## get\_sources

    $sources->get_sources;

Подтягивает исходники из git (если задан ["url"](#url)), если в src\_dir ещё нет репозитория.
При ошибке клонирования завершает программу. Ничего не возвращает.

## has\_git\_source

    my $has = $sources->has_git_source;

Проверяет, есть ли в src\_dir директория .git (признак git-репозитория).

Возвращает истину или ложь.


## Tracefile

# NAME

Code::CovTool::Tracefile - валидация и парсинг LCOV tracefile

# SYNOPSIS

    my $trace = Code::CovTool::Tracefile->new(
      tracefile => 'coverage.lcov',
      sources   => $cov_tool_sources,
    );
    $trace->validate_format;
    my $data = $trace->parse;

# DESCRIPTION

Читает и валидирует формат LCOV, парсит в структуру данных покрытия (HashRef).
Использует Code::CovTool::Sources для проверки путей исходников.

# CONSTRUCTOR

## new

    my $trace = Code::CovTool::Tracefile->new(
      tracefile => 'coverage.lcov',
      sources   => $cov_tool_sources,
    );

Создаёт экземпляр для работы с одним LCOV-файлом.

- **tracefile** (обязательный)

    Путь к файлу в формате LCOV.

- **sources** (обязательный)

    Объект Code::CovTool::Sources для проверки путей исходников при парсинге.

# METHODS

## parse

    my $data = $trace->parse;

Читает tracefile, для каждого пути вызывает "check\_path" in Code::CovTool::Sources,
собирает данные покрытия (DA, FN, FNDA и т.д.) в хэш по файлам. При ошибке
формата или несовпадении контрольных сумм завершает программу.

Возвращает ссылку на хэш: ключ — путь к файлу, значение — структура
{ sum => {...}, func => {...}, check => {...}, sumfnc => {...} }.

## validate\_format

    $trace->validate_format;

Проверяет синтаксис LCOV (SF, end\_of\_record, DA, FN, FNDA и т.д.) без загрузки
исходников. При ошибке завершает программу. Ничего не возвращает.


---

*Сгенерировано из POD документации подмодулей*
