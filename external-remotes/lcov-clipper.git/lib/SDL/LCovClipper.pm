package SDL::LCovClipper;

use strict;

# Функция generate_c_fun_cover получает в качестве параметров имя исходного html файла
# имя отфильтрованного файла и имена функций
sub clip
{
  my $in_file = shift;
  my $out_file = shift;
  my @identificators = @{shift;};
  my @flags;
  my @res;
  my @tmp_flags;
  my @src = get_src($in_file);

  my $src_str = list_to_str(@src);
  my $hdr_str = get_html_header_str($src_str);
  $hdr_str = insert_css_str($hdr_str);
  my @hdr = str_to_list($hdr_str);

  @hdr = patch_title(@hdr);

  my $ftr_str = get_html_footer_str($src_str);
  my @ftr = str_to_list($ftr_str);

  my $html_c_code_str = get_html_c_code_str($src_str);

  my @html_c_code = str_to_list($html_c_code_str);
  my @c_code = get_c_code(@html_c_code);

  @flags = mark_main_comment(@c_code);
  while (@identificators)
  {
    my $fun_name = shift @identificators;
    my @tmp_flags = mark_c_function($fun_name, @c_code);
    if (!@tmp_flags)
    {
      @tmp_flags = mark_c_macros($fun_name, @c_code);
    }
    if (!@tmp_flags)
    {
      die "Нет такого идентификатора: $fun_name\n";
    }
    @tmp_flags = expand_flags(@tmp_flags);
    @flags = unate_flags(\@flags, \@tmp_flags);
  }
  @flags = patch_holes(\@c_code, \@flags);
  @res = get_res_list(\@html_c_code, \@flags);
  @res = (@hdr, @res, @ftr);
  @res = insert_image(@res);
  put_res($out_file, @res);
}

#==========================================================================
# Функции конвертации из списочкного представления в строковое и обратно. =
#==========================================================================

# Функция str_to_list получает в качестве параметра строку, содержащую
# в себе переносы строк и разбивает ее на отдельные строки. Возвращает
# она массив с этими строкамм.
sub str_to_list
{
  my $str = shift @_;
  my @res = split(/\n/, $str);
  for (@res)
  {
    $_ .= "\n";
  }
  return @res;
}

# Функция list_to_str получает в качестве параметра массив строк, склеивает
# их в одну строку и возвращает эту строку
sub list_to_str
{
  my @src = @_;
  my $res = join('', @src);
  return $res;
}

#================================================
# Функции для роботы со списочным преставлением =
#================================================

# Функция patch_src получает в качесве параметра массив строк исходного
# html файла и при необходимости вставляет отсутсвтвующий перенос строки
# между заголовком и блоком c-кода. Возвращает она исправленный массив
# строк исходного html файла.
sub patch_src
{
  my @src = @_;
  for my $i (0..$#src)
  {
    if ($src[$i] =~ /><a name/)
    {
      my $s1 = $src[$i];
      $s1 =~ s/><a name.*/>/;
      my $s2 = $src[$i];
      $s2 =~ s/.*?><a name/<a name/;
      @src = (@src[0..$i-1], $s1, $s2, @src[$i+1..$#src]);
      last;
    }
  }
  return @src;
}

# Функция get_scr получает в качестве параметра имя исходного файла
# и воззваращает массив строк из этого файла
sub get_src
{
  my $in_name = shift;
  my @src;
  open my $in_file, '<', $in_name or die "Невозможно открыть файл $in_name: $!\n";
  while(my $s = <$in_file>)
  {
    push @src, $s;
  }
  close $in_file;
  return @src;
}

# Функция put_res получает в качестве параметра имя результирующего файла
# и массив строк для записи в этот файл
sub put_res
{
  my $out_name = shift;
  my @trt = @_;
  open my $out_file, '>', $out_name or die "Невозможно открыть файл $out_name: $!\n";
  for (@trt)
  {
    print $out_file $_;
  }
  close $out_file;
}

# Функция get_html_header в качестве параметра принимает массив исходного файла
# и возвращает массив строк html-шапки
sub get_html_header
{
  my @hdr;
  for (@_)
  {
    if(!($_=~/^<a name="\d+">.+ : .*<\/a>$/))
    {
      push @hdr, $_;
    }
    else
    {
      return @hdr;
    }
  }
}

# Функция get_html_footer в качаестве параметра принимаем массив строк
# исходного файла и возвращает массив строк html-подвала
sub get_html_footer
{
  my @bend;
  while (!((my $i = pop @_) =~/^<a name="\d+">.+ : .*<\/a>$/))
  {
    unshift @bend, $i;
  }
  return @bend;
}

# Функция get_html_c_code в качестве параметра принимает массив строк
# исходного файла и возвращает массив html строк, содержащих C код
sub get_html_c_code
{
  my @html_c_code;
  for (@_)
  {
    if($_=~/^<a name="\d+">.+ : .*<\/a>$/)
    {
      push @html_c_code, $_;
    }
  }
  return @html_c_code;
}

# Функция get_c_code в качестве параметра принимает массив html строк,
# содержащих C код и возвращает массив строк C кода.
sub get_c_code
{
  my @c_code;
  for (@_)
  {
    push @c_code, $_;
    $c_code[-1] =~s/<a name="\d+"><span class="lineNum">\s+\d+ <\/span>(<span class="line(No)?Cov">\s+\d+)*\s+: (.*?)(<\/span>)?<\/a>/$3/;
  }
  return @c_code;
}

# Функция find_single_comment в качестве параметра принимает массив строк
# исследуемого C кода и в случае успеха воздвращает пару номеров строк
# начала и конца первого комментария к коду и массив кода с "выкушенным"
# найденным комментарием.
# В случае неуспеха возвращается пустой массив.
sub find_single_comment
{
  my @src = @_;
  my @res;

  my $line_number = 0;
  while (! ($src[$line_number] =~/^\s*?\/\*/))
  {
    if ($src[$line_number] =~/\S/)
    {
      return @res;
    }
    else
    {
      $line_number++;
    }
  }
  push @res, $line_number;
  while (! ($src[$line_number] =~/.*?\*\//))
  {
    $src[$line_number] =~s/^.*$//;
    $line_number++;
  }
  push @res, $line_number;
  $src[$line_number] =~s/.*?\*\///;
  push @res, @src;
  return @res;
}

# Функция find_single_hole в качестве параметра принимает номер сторки,
# с которой мы начинаем поиск дыры в массиве флагов и сам массив флагов.
# В случае успеха воздвращает пару номеров строк
# начала и конца первой найденной дыры.
# В случае неуспеха возвращается пустой массив.
sub find_single_hole
{
  my $line_number = shift;
  my @flags = @_;
  my @res;

  if ($line_number > $#flags)
  {
    return @res;
  }
  while ($flags[$line_number])
  {
    $line_number++;
    if ($line_number > $#flags)
    {
      return @res;
    }
  }
  push @res, $line_number;
  while (! ($flags[$line_number]))
  {
    $line_number++;
    if ($line_number > $#flags)
    {
      push @res, ($line_number-1);
      return @res;
    }
  }
  push @res, ($line_number-1);
  return @res;
}

# Функция patch_holes заделывает маленькие дыры. В качестве параметров
# patch_holes получает ссылки на массив c-кода и на массив флагов. Возврацает
# она пропатченный массив флагов
sub patch_holes
{
  my @src = @{shift;};
  my @flags = @{shift;};
# Будем законопачевать все маленькие дыры, на которые наткнемся.
# Если мы попали в дыру, то раз она не законопачена - значит она большая,
# можно ее пропустить. Если мы не в дыре, то двигаемся дальше, пока не
# уткнемся в дыру. Когда мы уткнулись в дыру - если она маленькая, то мы
# ее законопачиваем. Можем двигаться дальше.
# Есть проблема с обработкой начала и конца массива флагов.
# Проблема начала: если массив флагов начинается с маленькой дырыки.
# Тогда мы оказываемся в маленькой дырке, чего штатно не должно произойти.
# И алгоритм считает, что это большая дырка и не законопачивает ее.
# Проблема конца аналогична: если массив флагов заканчивается маленькой
# дыркой. Тогда она алгоритмом будет воспринята как бльшая и не будет
# законопачена.
# Эти проблемы можно решить, заканопатив маленькие дырки в начале и конце
# массива флагов заранее, до выполнения основного алгоритма.
  $flags[1] = 1 if $flags[2];
  $flags[0] = 1 if $flags[1];
  $flags[-2] = 1 if $flags[-3];
  $flags[-1] = 1 if $flags[-2];
  for (0..$#flags)
  {
    next if !$flags[$_]; # мы в дырке, двигаемся дальше
    next if $flags[$_+1]; # мы не в дырке и дальше не дыра, двигаемся дальше
    next if !$flags[$_+2] && !$flags[$_+3]; # уперлись в большую дыру, двигаемся дальше
    ($flags[$_+1], $flags[$_+2]) = (1,1); # уперлись в маленькую дырку, конопатим и двигаемся дальше
  }
  return @flags;
}

# Функция mark_main_comment получает в качестве параметра массив строк
# исследуемого C кода и возвращает массив флагов для общего комментария
# к C кодую
sub mark_main_comment
{
  my @c_code = @_;
  my @comment_lines_numbers;
  my @flags;
  while(my @res = find_single_comment(@c_code))
  {
    for(1..2)
    {
      push @comment_lines_numbers, (shift @res);
    }
    @c_code = @res;
  }
  if (@comment_lines_numbers)
  {
    for ($comment_lines_numbers[0]..$comment_lines_numbers[-1]+7)
    {
      $flags[$_] = 1;
    }
  }
  return @flags;
}

# Функция mark_c_function  в качестве параметров получает  имя искомой
# функции
# и массив строк, содержащих C код. Возвращает массив флагов для
# искомого идентефикатора. 
# В случае неудачи возвращает пустой список.
sub mark_c_function
{
  my $fn_name = shift;
  my @src = @_;
  my @res;
  my $fn_line;
  my $br_line;
  my $end_line;
  my $start_line;
  my @flags;
  for my $i (0..$#src)
  {
    if ($src[$i] =~/^$fn_name\s*?\(/)
    {
      for my $k ($i..$#src)
      {
        if ($src[$k] =~ /\)\s*?;/)
        {
          return @flags;
        }
        if ($src[$k] =~/\)/ && $src[$k+1] =~/^\{/)
        {
          $br_line = $k;
          $fn_line = $i;
          last;
        }
      }
      if ($fn_line)
      {
        last;
      }
    }
  }
  unless ($fn_line)
  {
    return @flags;
  }
  for ($br_line+1..$#src)
  {
    if (@src[$_] =~ /^\}/)
    {
      $end_line = $_;
      last;
    }
  }
  $start_line = $fn_line-1;
  while(@res = find_single_comment_fn($fn_line-2, @src))
  {
    $start_line = shift @res;
    shift @res;
    @src = @res;
  }
  for ($start_line..$end_line)
  {
    $flags[$_] = 1;
  }
  return @flags;
}

# Функция mark_c_macros  в качестве параметров получает  имя искомого
# идентификатора
# и массив строк, содержащих C код. Возвращает массив флагов для
# искомого идентефикатора. Добавляет по три строки до и после для красоты.
# В случае неудачи аварийно завершает программу.
sub mark_c_macros
{
  my $macros_name = shift;
  my @src = @_;
  my $fn_line;
  my $end_line;
  my $start_line;
  my @flags;
  for (0..$#src)
  {
    if ($src[$_] =~/^#define\s+?$macros_name\s*?\(/)
    {
      $fn_line = $_;
      last;
    }
  }
  unless ($fn_line)
  {
    return @flags;
  }
  ($start_line, $end_line) = ($fn_line, $fn_line);
  while ($src[$end_line] =~/\\\s*?$/)
  {
    $end_line++;
  }
  for ($start_line..$end_line)
  {
    $flags[$_] = 1;
  }
  return @flags;
}

# Функция expand_flags получает в качестве параметров массив флагов и добавляет
# к нему две единицы спереди и три сзади.
sub expand_flags
{
  my @flags = @_;
  for (0..$#flags)
  {
    if ($flags[$_])
    {
      ($flags[$_-2], $flags[$_-1]) = (1, 1);
      last;
    }
  }
  push @flags, (1,1,1);
  return @flags;
}

# Функция find_single_comment_fn в качестве параметров принимает номер строки,
# после которой начинается описание функции и массив строк
# исследуемого C кода. В случае успеха воздвращает пару номеров строк
# начала и конца последнего комментария к функции и массив кода с "выкушенным"
# найденным комментарием.
# В случае неуспеха возвращается пустой массив.
sub find_single_comment_fn
{
  my $line_number = shift;
  my @src = @_;
  my @res;


  while (! ($src[$line_number] =~/\*\/\s*?$/))
  {
    return @res if($src[$line_number] =~/\S/);
    $line_number--;
  }
  unshift @res, $line_number;
  while (! ($src[$line_number] =~/\/\*.*?$/))
  {
    $src[$line_number] =~s/^.*$//;
    $line_number--;
  }
  unshift @res, $line_number;
  $src[$line_number] =~s/\/\*.*?$//;
  push @res, @src;
  return @res;
}

# Функция get_res_list в качестве параметров принимаем ссылки на массив исходных
# строк и на массив флагов. Возвращает она массив итогового отчета.
sub get_res_list
{
  my @src = @{shift;};
  my @flags = @{shift;};
  my @res;
  if (!($flags[0]))
  {
    push @res, "<br>...<br>\n";
  }
  for (0..$#src)
  {
    if ($flags[$_])
    {
      push @res, $src[$_];
      if (($_ != $#src) && (!($flags[$_+1])))
      {
        push @res, "<br>...<br>\n";
      }
    }
  }
  return @res;
}

# Функция unate_flags в качестве параметров получает ссылки на два массива
# флагов и возвращает объединенный массив флагов.
sub unate_flags
{
  my @flags1 = @{shift;};
  my @flags2 = @{shift;};
  my @flags;
  for (0..$#flags1)
  {
    $flags[$_] = $flags1[$_] if ($flags1[$_]);
  }
  for (0..$#flags2)
  {
    $flags[$_] = $flags2[$_] if ($flags2[$_]);
  }
  return @flags;
}

# Функция insert_css в качестве параметра получает массив с заголовком 
# html-файла и возвращает этот заголовок с вставленной таблицей стилей
sub insert_css
{
  my @header = @_;

  my @res; 
  
  foreach (@header)
  {
    if ($_=~/gcov\.css/)
    {
      push @res, "<style>\n";
      push @res, get_CSS();
      push @res, "</style>\n";
    }
    else
    {
      push @res, $_;
    }
  }

  return @res;
}


# Функция insert_image получает в качестве параметра массив строк html-файла
# и возвращает массив строк с вставлением картинки через Base64
sub insert_image
{
  my @src = @_;
  for (@src)
  {
    $_ =~s/<img src=".+?"/<img src="data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAABGdBTUEAALGPC\/xhBQAAAAZQTFRF\/\/\/\/AAAAVcLTfgAAAAF0Uk5TAEDm2GYAAAABYktHRACIBR1IAAAACXBIWXMAAAsSAAALEgHS3X78AAAAB3RJTUUH0gcTDwgZxEBWEAAAAApJREFUeJxjYAAAAAIAAUivpHEAAAAASUVORK5CYII="/;
  }
  return @src;
}

# Функция patch_title получает в качестве параметра массив строк заголовка html-файла
# и возвращает массив строк заголовка html-файла с исправленым тайтлом.
sub patch_title
{
  my @src = @_;
  my @res;
  for (@src)
  {
    if($_=~/Current view:/)
    {
      $_=~s/Current view://;
      push @res, $_;
    }
    elsif ($_=~/top level/)
    {
      $_=~s/<a href=.+?>//g;
      $_=~s/<\/a>//g;
      $_=~s/top level - //;
      $_=~s/<span.+?\/span>//;
      $_=~s/ - //;
      push @res, $_;
    }
    else
    {
      push @res, $_;
    }
  }
  return @res;
}

#=================================================
# Функции для работы со строковым представлением =
#=================================================

# Функция get_html_header_str в качестве параметра принимает строку исходного файла
# и возвращает строку html-шапки
sub get_html_header_str
{
  my $src = shift @_;
  $src =~ s/<a name="1">.*$//s;
  return $src;
}

# Функция get_html_footer_str в качаестве параметра принимаем строку
# исходного файла и возвращает строку html-подвала
sub get_html_footer_str
{
  my $src = shift;
  $src =~ s/^.*<\/span><\/a>//s;
  return $src;
}

# Функция get_html_c_code_str в качестве параметра принимает строку
# исходного файла и возвращает строку html кода, содержащего C код
sub get_html_c_code_str
{
  my $html_c_code = shift;
  $html_c_code =~ s/^.*(<a name="1".*<\/span><\/a>).*/$1/s;
  return $html_c_code;
}

# Функция insert_css_str в качестве параметра получает массив с заголовком
# html-файла и возвращает этот заголовок с вставленной таблицей стилей
sub insert_css_str
{
  my $header = shift @_;

  my $str = list_to_str(get_CSS());
  $str = "<style>\n".$str."</style>";
  $header =~ s/<link rel="stylesheet".*?>/$str/s;
  return $header;
}

sub get_CSS
{
  return <<'CSS';
/* All views: initial background and text color */
body
{
  color: #000000;
  background-color: #FFFFFF;
}

/* All views: standard link format*/
a:link
{
  color: #284FA8;
  text-decoration: underline;
}

/* All views: standard link - visited format */
a:visited
{
  color: #00CB40;
  text-decoration: underline;
}

/* All views: standard link - activated format */
a:active
{
  color: #FF0040;
  text-decoration: underline;
}

/* All views: main title format */
td.title
{
  text-align: center;
  padding-bottom: 10px;
  font-family: sans-serif;
  font-size: 20pt;
  font-style: italic;
  font-weight: bold;
}

/* All views: header item format */
td.headerItem
{
  text-align: right;
  padding-right: 6px;
  font-family: sans-serif;
  font-weight: bold;
  vertical-align: top;
  white-space: nowrap;
}

/* All views: header item value format */
td.headerValue
{
  text-align: left;
  color: #284FA8;
  font-family: sans-serif;
  font-weight: bold;
  white-space: nowrap;
}

/* All views: header item coverage table heading */
td.headerCovTableHead
{
  text-align: center;
  padding-right: 6px;
  padding-left: 6px;
  padding-bottom: 0px;
  font-family: sans-serif;
  font-size: 80%;
  white-space: nowrap;
}

/* All views: header item coverage table entry */
td.headerCovTableEntry
{
  text-align: right;
  color: #284FA8;
  font-family: sans-serif;
  font-weight: bold;
  white-space: nowrap;
  padding-left: 12px;
  padding-right: 4px;
  background-color: #DAE7FE;
}

/* All views: header item coverage table entry for high coverage rate */
td.headerCovTableEntryHi
{
  text-align: right;
  color: #000000;
  font-family: sans-serif;
  font-weight: bold;
  white-space: nowrap;
  padding-left: 12px;
  padding-right: 4px;
  background-color: #A7FC9D;
}

/* All views: header item coverage table entry for medium coverage rate */
td.headerCovTableEntryMed
{
  text-align: right;
  color: #000000;
  font-family: sans-serif;
  font-weight: bold;
  white-space: nowrap;
  padding-left: 12px;
  padding-right: 4px;
  background-color: #FFEA20;
}

/* All views: header item coverage table entry for ow coverage rate */
td.headerCovTableEntryLo
{
  text-align: right;
  color: #000000;
  font-family: sans-serif;
  font-weight: bold;
  white-space: nowrap;
  padding-left: 12px;
  padding-right: 4px;
  background-color: #FF0000;
}

/* All views: header legend value for legend entry */
td.headerValueLeg
{
  text-align: left;
  color: #000000;
  font-family: sans-serif;
  font-size: 80%;
  white-space: nowrap;
  padding-top: 4px;
}

/* All views: color of horizontal ruler */
td.ruler
{
  background-color: #6688D4;
}

/* All views: version string format */
td.versionInfo
{
  text-align: center;
  padding-top: 2px;
  font-family: sans-serif;
  font-style: italic;
}

/* Directory view/File view (all)/Test case descriptions:
   table headline format */
td.tableHead
{
  text-align: center;
  color: #FFFFFF;
  background-color: #6688D4;
  font-family: sans-serif;
  font-size: 120%;
  font-weight: bold;
  white-space: nowrap;
  padding-left: 4px;
  padding-right: 4px;
}

span.tableHeadSort
{
  padding-right: 4px;
}

/* Directory view/File view (all): filename entry format */
td.coverFile
{
  text-align: left;
  padding-left: 10px;
  padding-right: 20px; 
  color: #284FA8;
  background-color: #DAE7FE;
  font-family: monospace;
}

/* Directory view/File view (all): bar-graph entry format*/
td.coverBar
{
  padding-left: 10px;
  padding-right: 10px;
  background-color: #DAE7FE;
}

/* Directory view/File view (all): bar-graph outline color */
td.coverBarOutline
{
  background-color: #000000;
}

/* Directory view/File view (all): percentage entry for files with
   high coverage rate */
td.coverPerHi
{
  text-align: right;
  padding-left: 10px;
  padding-right: 10px;
  background-color: #A7FC9D;
  font-weight: bold;
  font-family: sans-serif;
}

/* Directory view/File view (all): line count entry for files with
   high coverage rate */
td.coverNumHi
{
  text-align: right;
  padding-left: 10px;
  padding-right: 10px;
  background-color: #A7FC9D;
  white-space: nowrap;
  font-family: sans-serif;
}

/* Directory view/File view (all): percentage entry for files with
   medium coverage rate */
td.coverPerMed
{
  text-align: right;
  padding-left: 10px;
  padding-right: 10px;
  background-color: #FFEA20;
  font-weight: bold;
  font-family: sans-serif;
}

/* Directory view/File view (all): line count entry for files with
   medium coverage rate */
td.coverNumMed
{
  text-align: right;
  padding-left: 10px;
  padding-right: 10px;
  background-color: #FFEA20;
  white-space: nowrap;
  font-family: sans-serif;
}

/* Directory view/File view (all): percentage entry for files with
   low coverage rate */
td.coverPerLo
{
  text-align: right;
  padding-left: 10px;
  padding-right: 10px;
  background-color: #FF0000;
  font-weight: bold;
  font-family: sans-serif;
}

/* Directory view/File view (all): line count entry for files with
   low coverage rate */
td.coverNumLo
{
  text-align: right;
  padding-left: 10px;
  padding-right: 10px;
  background-color: #FF0000;
  white-space: nowrap;
  font-family: sans-serif;
}

/* File view (all): "show/hide details" link format */
a.detail:link
{
  color: #B8D0FF;
  font-size:80%;
}

/* File view (all): "show/hide details" link - visited format */
a.detail:visited
{
  color: #B8D0FF;
  font-size:80%;
}

/* File view (all): "show/hide details" link - activated format */
a.detail:active
{
  color: #FFFFFF;
  font-size:80%;
}

/* File view (detail): test name entry */
td.testName
{
  text-align: right;
  padding-right: 10px;
  background-color: #DAE7FE;
  font-family: sans-serif;
}

/* File view (detail): test percentage entry */
td.testPer
{
  text-align: right;
  padding-left: 10px;
  padding-right: 10px; 
  background-color: #DAE7FE;
  font-family: sans-serif;
}

/* File view (detail): test lines count entry */
td.testNum
{
  text-align: right;
  padding-left: 10px;
  padding-right: 10px; 
  background-color: #DAE7FE;
  font-family: sans-serif;
}

/* Test case descriptions: test name format*/
dt
{
  font-family: sans-serif;
  font-weight: bold;
}

/* Test case descriptions: description table body */
td.testDescription
{
  padding-top: 10px;
  padding-left: 30px;
  padding-bottom: 10px;
  padding-right: 30px;
  background-color: #DAE7FE;
}

/* Source code view: function entry */
td.coverFn
{
  text-align: left;
  padding-left: 10px;
  padding-right: 20px; 
  color: #284FA8;
  background-color: #DAE7FE;
  font-family: monospace;
}

/* Source code view: function entry zero count*/
td.coverFnLo
{
  text-align: right;
  padding-left: 10px;
  padding-right: 10px;
  background-color: #FF0000;
  font-weight: bold;
  font-family: sans-serif;
}

/* Source code view: function entry nonzero count*/
td.coverFnHi
{
  text-align: right;
  padding-left: 10px;
  padding-right: 10px;
  background-color: #DAE7FE;
  font-weight: bold;
  font-family: sans-serif;
}

/* Source code view: source code format */
pre.source
{
  font-family: monospace;
  white-space: pre;
  margin-top: 2px;
}

/* Source code view: line number format */
span.lineNum
{
  background-color: #EFE383;
}

/* Source code view: format for lines which were executed */
td.lineCov,
span.lineCov
{
  background-color: #CAD7FE;
}

/* Source code view: format for Cov legend */
span.coverLegendCov
{
  padding-left: 10px;
  padding-right: 10px;
  padding-bottom: 2px;
  background-color: #CAD7FE;
}

/* Source code view: format for lines which were not executed */
td.lineNoCov,
span.lineNoCov
{
  background-color: #FF6230;
}

/* Source code view: format for NoCov legend */
span.coverLegendNoCov
{
  padding-left: 10px;
  padding-right: 10px;
  padding-bottom: 2px;
  background-color: #FF6230;
}

/* Source code view (function table): standard link - visited format */
td.lineNoCov > a:visited,
td.lineCov > a:visited
{  
  color: black;
  text-decoration: underline;
}  

/* Source code view: format for lines which were executed only in a
   previous version */
span.lineDiffCov
{
  background-color: #B5F7AF;
}

/* Source code view: format for branches which were executed
 * and taken */
span.branchCov
{
  background-color: #CAD7FE;
}

/* Source code view: format for branches which were executed
 * but not taken */
span.branchNoCov
{
  background-color: #FF6230;
}

/* Source code view: format for branches which were not executed */
span.branchNoExec
{
  background-color: #FF6230;
}

/* Source code view: format for the source code heading line */
pre.sourceHeading
{
  white-space: pre;
  font-family: monospace;
  font-weight: bold;
  margin: 0px;
}

/* All views: header legend value for low rate */
td.headerValueLegL
{
  font-family: sans-serif;
  text-align: center;
  white-space: nowrap;
  padding-left: 4px;
  padding-right: 2px;
  background-color: #FF0000;
  font-size: 80%;
}

/* All views: header legend value for med rate */
td.headerValueLegM
{
  font-family: sans-serif;
  text-align: center;
  white-space: nowrap;
  padding-left: 2px;
  padding-right: 2px;
  background-color: #FFEA20;
  font-size: 80%;
}

/* All views: header legend value for hi rate */
td.headerValueLegH
{
  font-family: sans-serif;
  text-align: center;
  white-space: nowrap;
  padding-left: 2px;
  padding-right: 4px;
  background-color: #A7FC9D;
  font-size: 80%;
}

/* All views except source code view: legend format for low coverage */
span.coverLegendCovLo
{
  padding-left: 10px;
  padding-right: 10px;
  padding-top: 2px;
  background-color: #FF0000;
}

/* All views except source code view: legend format for med coverage */
span.coverLegendCovMed
{
  padding-left: 10px;
  padding-right: 10px;
  padding-top: 2px;
  background-color: #FFEA20;
}

/* All views except source code view: legend format for hi coverage */
span.coverLegendCovHi
{
  padding-left: 10px;
  padding-right: 10px;
  padding-top: 2px;
  background-color: #A7FC9D;
}
CSS
}


1;
