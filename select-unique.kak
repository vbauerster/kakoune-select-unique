define-command select-unique -override -params ..2 %{
    try %{
        exec -draft '<a-space><esc><a-,><esc>'
    } catch %{
        fail 'Only one selection, cannot filter'
    }
    eval %sh{
        order="NORMAL"
        unique_where="OUTPUT"
        i=1
        for arg do
            if [ "$arg" = '-strict' ]; then
                unique_where="INPUT"
            elif [ "$arg" = '-reverse' ]; then
                order="REVERSE"
            else
                printf "fail \"Unrecognized argument '%s'\"" "%arg{$i}"
                exit
            fi
            i=$((i + 1))
        done
        perl - "$unique_where" "$order" <<'EOF'
use strict;
use warnings;

my $unique_in_input = shift;
$unique_in_input = ($unique_in_input eq "INPUT");
my $reverse = shift;
$reverse = ($reverse eq "REVERSE");

my $command_fifo_name = $ENV{"kak_command_fifo"};
my $response_fifo_name = $ENV{"kak_response_fifo"};

sub parse_shell_quoted {
    my $str = shift;
    my @res;
    my $elem = "";
    while (1) {
        if ($str !~ m/\G'([\S\s]*?)'/gc) {
            exit(1);
        }
        $elem .= $1;
        if ($str =~ m/\G *$/gc) {
            push(@res, $elem);
            $elem = "";
            last;
        } elsif ($str =~ m/\G\\'/gc) {
            $elem .= "'";
        } elsif ($str =~ m/\G */gc) {
            push(@res, $elem);
            $elem = "";
        } else {
            exit(1);
        }
    }
    return @res;
}

sub read_array {
    my $what = shift;
    open (my $command_fifo, '>', $command_fifo_name);
    print $command_fifo "echo -quoting shell -to-file $response_fifo_name -- $what";
    close($command_fifo);
    # slurp the response_fifo content
    open (my $response_fifo, '<', $response_fifo_name);
    my $response_quoted = do { local $/; <$response_fifo> };
    close($response_fifo);
    return parse_shell_quoted($response_quoted);
}

my @selections = read_array("%val{selections}");
my @selections_desc = read_array("%val{selections_desc}");

my @result_descs;

if ($unique_in_input) {
    my %occurrences_count;
    for my $sel (@selections) {
        if (exists $occurrences_count{$sel}) {
            my $prev_val = $occurrences_count{$sel};
            $occurrences_count{$sel} = $prev_val + 1;
        } else {
            $occurrences_count{$sel} = 1;
        }
    }
    for my $i (0 .. scalar(@selections) - 1) {
        my $sel = $selections[$i];
        my $desc = $selections_desc[$i];
        if ($occurrences_count{$sel} == 1) {
            if (!$reverse) {
                push(@result_descs, $desc );
            }
        } else {
            if ($reverse) {
                push(@result_descs, $desc );
            }
        }
    }
} else {
    # unique in output case
    my %occurred;
    for my $i (0 .. scalar(@selections) - 1) {
        my $sel = $selections[$i];
        my $desc = $selections_desc[$i];
        if (exists $occurred{$sel}) {
            if ($reverse) {
                push(@result_descs, $desc );
            }
        } else {
            $occurred{$sel} = 1;
            if (!$reverse) {
                push(@result_descs, $desc );
            }
        }
    }
}

if (scalar(@result_descs) == 0) {
    # nothing to select, invalid input
    print("fail 'no selections remaining' ;");
} else {
    print("select");
    for my $desc (@result_descs) { 
        print(" '$desc'");
    }
    print(" ;");
}
EOF
    }
}
