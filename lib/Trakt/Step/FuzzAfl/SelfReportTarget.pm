package Trakt::Step::FuzzAfl::SelfReportTarget;

use Moose::Role;
use utf8;



sub get_tt
{
  my $self = shift;
  my $name = shift // "main";

  die "Неизвестный шаблон '$name'" if $name ne "main";

  return "
Запуск исследования произвоится командой:

[% FOREACH pane_dsk IN self.tmux_runner_conf.panes -%]
  [%IF pane_dsk.fuzzer -%]
    [% afl_run_command = pane_dsk.fuzzer.command -%]
  [% END -%]
[% END -%]

```
[% afl_run_command %]

```

Содержимое используемого при запуске файла конфигурации `afl_runner.conf`:

```
[% JSON.encode(self.afl_runner_conf) %]
```



Исходный скод скрипта запуска `run_aflpp_swarm.pl`:

```
[% self.find_bin('run_aflpp_swarm.pl').slurp_utf8 %]
```



";
}



1;
