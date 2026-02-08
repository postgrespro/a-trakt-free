package Trakt::CommandExecutorRole;

# ************** CommandExecutorRole *******************
# Роль CommandExecutorRole будет применяться к классам Trakt,
# Step и Target. В этих классах должны быть реализованны методы
# run, cache_dir, exchange_dir и trakt. В роли CommandExecutorRole эти
# методы помечены как requires.
# В cache_dir пишется файл run_command.log, в exchange_dir/reports
# пишется файл commands.json.
# run_command.log создается на случай, если что-то пойдет нетак,
# поэтому новые записи к нему только добавляются. commands.json
# используется для автоматической генерации отчетов, поэтому при
# вызове метода save_commands он перезаписывается заново.
# Функционал роли:
# 1. Наличие метода find_bin, который исполнимый файл по имени.
# Поиск производится либо в bin директории конфига тракта, либо
# в тракт-глобальном bin.
# 2. Наличие метода run_command, которому на вход подаются тег,
# команда shell, которую необходимо выполнить и опции запуска
# команды.
# 3. В скрытом атрибуте _commands_stash сохраняются эти теги и
# команды shell с их тегами.
# 4. Выполняется команда shell с сохранением лога выполнения в
# лог-файле.
# 5. Наличие метода save_commands, который сохраняет в json-файле
# команды из _commands_stash с их тегами.
# 6. Метод save_commands вызывается в модификаторе after метода run, если
# commands_stash не пустой. Это гарантирует, что метод
# save_commands будет вызван после всех вызовов метода run_command.
# В случае класса Targets это исключение, штатным образом в классе
# Targets все, что должно выполниться после после основного блока
# core_run, добавляется в метод after_run.

use Moose::Role;
use warnings;
use JSON;
use Path::Tiny;
use String::ShellQuote;

requires 'cache_dir';
requires 'exchange_dir';
requires 'run';
requires 'trakt';

with "SDL::Trakt::Witness::Role";

sub find_bin
{
  my $self = shift;
  my $bin = shift;
  my $local_bin = $self->trakt->conf_dir."/bin/".$bin;
  my $top_bin = $self->trakt->top_dir."/bin/".$bin;

  return path($top_bin)   if (-x $top_bin);
  return path($local_bin) if(-x $local_bin);
  return undef;
}

sub run_command
{
  my $self = shift;
  my $tag = shift;
  my $command = shift;
  my $opts = shift || {};

  $self->cache_dir->mkdir();
  my $command_output = $self->cache_dir->tempfile(TEMPLATE => "$tag.XXXXXXXX");

  my $real_command = "bash -c ".shell_quote("set -o pipefail ; ( $command ) 2>&1 | tee -a $command_output");  # set -o pipefail правильно передает код возврата через пайп

  $self->log_before_command($tag, $command, $real_command);

  if ($opts->{no_out})
  {
    print "Silently executing: $command\n";
    `$real_command`;
     die "Execution failed" if $?;
  } else
  {
    print "Executing: $command\n";
    system($real_command);
    die "Execution failed" if $?;
  }

  $self->log_after_command($tag, $command, $real_command, $command_output->slurp);
}

1;
