package Range{

  use strict;
  use warnings;
  use Scalar::Util qw(looks_like_number);

  our $trimDecimal = sub{ return 0 + sprintf "%.3f", shift; };
  
  sub new{
    my ($class, $min, $max, $trimDecimalFunction) = @_;
    my $type = "+";
    die "Only either '+' symbol, '-' symbol, or no symbol at all allowed for type.\n" if (defined $type && $type !~ /^[\+\-]$/);
    $trimDecimalFunction = sub{ return shift; } if (!defined $trimDecimalFunction);
    die "Only CODE values allowed.\n" if (ref $trimDecimalFunction ne "CODE");
    my $self = bless{
      max => undef,
      min => undef,
      type => $type,
      trimDecimalFunction => $trimDecimalFunction
    }, $class;
    setMax($self, $max);
    setMin($self, $min);
    return $self;
  }

  sub getMax{ return shift->{max}; }

  sub max{ return shift->getMax; }

  sub getMin{ return shift->{min}; }

  sub min{ return shift->getMin; }

  #Josafa
  sub getHalf{
    my $self = shift;
    return $trimDecimal->($self->{min} + ($self->{max} - $self->{min}) / 2);
  }
  
  sub getRawValues{
    my $self = shift;
    return $self->getMin(), $self->getMax();
  }

  sub trimDecimalFunction{ return shift->getTrimDecimalFunction; }

  sub getTrimDecimalFunction{ return shift->{trimDecimalFunction}; }

  sub getACopyMovedBy{
    my ($self, $lapse) = @_;
    die "You must provide a numeric value for lapse.\n" if (!defined $lapse);
    return new Range($self->runTrimFunction($self->getMin() + $lapse), $self->runTrimFunction($self->getMax() + $lapse), $self->getTrimDecimalFunction());
  }

  #Josafa
  sub getACopyLeftMovedBy{
    my ($self, $lapse) = @_;
    die "You must provide a numeric value for lapse.\n" if (!defined $lapse);
    return new Range($self->runTrimFunction($self->getMin() + $lapse), $self->getMax(), $self->getTrimDecimalFunction());
  }
  
  #Josafa
  sub getACopyRightMovedBy{
    my ($self, $lapse) = @_;
    die "You must provide a numeric value for lapse.\n" if (!defined $lapse);
    return new Range($self->getMin(), $self->runTrimFunction($self->getMax() + $lapse), $self->getTrimDecimalFunction());
  }
  
  #Josafa
  sub getACopyExpandedLeftRight{
    my ($self, $lapseLeft, $lapseRight) = @_;
    die "You must provide a numeric value for lapse.\n" if (!defined $lapseLeft || !defined $lapseRight);
    return new Range($self->runTrimFunction($self->getMin() - $lapseLeft), $self->runTrimFunction($self->getMax() + $lapseRight), $self->getTrimDecimalFunction());
  }

  #Josafa
  sub getACopyShrinkedCenter{
    my $self = shift;
    return new Range($self->runTrimFunction($self->getMin() + (($self->getMax() - $self->getMin()) / 2) - 0.001 ), $self->runTrimFunction($self->getMin() + (($self->getMax() - $self->getMin()) / 2) + 0.001 ), $self->getTrimDecimalFunction());
  }
  
  sub assertRef{
    my ($self, %params) = @_;
    my $obj = $params{obj} if (exists $params{obj});
    my $rgx = $params{errRgx} if (exists $params{errRgx});
    my $type = $params{type} if (exists $params{type});
    my $paramName = $params{name} if (exists $params{name});
    my $dieOnUndef = $params{dieOnUndef} if (exists $params{dieOnUndef});
    my $title = (caller(1))[3] . (defined $paramName ? " (by $paramName)" : "") . ":";
    my $msg = "";
    if (defined $obj){
      $msg .= "\\ Expected type: $type\n  Provided type: " . ref $obj if (defined $type && ref $obj ne $type);
      $msg .= "\\ Unexpected value." if (defined $rgx && ref $obj eq "" && $obj =~ /$rgx/);
      if ($msg !~ /^\s*$/){
        $msg = "Assertion error.\n" . $msg;
        $msg =~ s/^/    /gm;
        die "$title\n$msg\n";
      }
    }
    else{
      die "$title\n    No value provided.\n" if (defined $dieOnUndef && $dieOnUndef);
    }
  }
  
  sub moveTo{
    my $self = shift;
    my ($stamp) = @_;
    assertRef(obj => $stamp, type => "", name => 'stamp', errRgx => qr/^\s*$/, dieOnUndef => 1);
    return $self->moveBy($stamp - $self->getMin);
  }

  sub moveBy{
    my $self = shift;
    my ($lapse) = @_;
    assertRef(obj => $lapse, type => "", name => 'lapse', errRgx => qr/^\s*$/, dieOnUndef => 1);
    if ($lapse != 0){
      if ($lapse > 0){
        $self->setMax($self->getMax + $lapse);
        $self->setMin($self->getMin + $lapse);
      }
      elsif ($lapse < 0){
        $self->setMin($self->getMin + $lapse);
        $self->setMax($self->getMax + $lapse);
      }
    }
    return $self;
  }

  sub scale{
    my ($self, $factor) = @_;
    die "Provide a number for factor." if (!defined $factor || $factor =~ /^\s*$/);
    die "Factor cannot be zero." if ($factor == 0);
    my $intervalTrimFunction = $self->getTrimDecimalFunction();
    $self->{max} = $intervalTrimFunction->($self->getMax() * $factor);
    $self->{min} = $intervalTrimFunction->($self->getMin() * $factor);
    return $self;
  }

  sub runTrimFunction{
    my ($self, $val) = @_;
    return $self->{trimDecimalFunction}->($val);
  }

  sub doTrim{
    my $self = shift;
    $self->setMin($self->getMin);
    $self->setMax($self->getMax);
    return $self;
  }

  sub setMax{
    my ($self, $max) = @_;
    die "You must provide a numeric value for max.\n" unless looks_like_number($max);
    $max = $self->runTrimFunction($max);
    assertBounds($self, $self->{min}, $max);
    $self->{max} = $max;
  }

  sub setMin{
    my ($self, $min) = @_;
    die "You must provide a numeric value for min.\n" unless looks_like_number($min);
    $min = $self->runTrimFunction($min);
    assertBounds($self, $min, $self->{max});
    $self->{min} = $min;
  }

  sub getDiff{
    my $self = shift;
    die "Both max and min must have a numeric value assigned.\n" if (!defined $self->{max}  || !defined $self->{min});
    return $trimDecimal->($self->{max} - $self->{min});
  }

  sub duration{
    my $self = shift;
    return $trimDecimal->($self->{max} - $self->{min});
  }
  
  #Josafa
  sub getDuration{
    my $self = shift;
    return $trimDecimal->($self->{max} - $self->{min});
  }
  
  sub assertBounds{
    my ($self, $min, $max) = @_;
    return if (!defined $self->{type});
    my $symbol = $self->{type};
    die "Maximun value must be greater than minimum value ($symbol).\n\tmax: $max\n\tmin: $min\n" if ($symbol eq "+" && defined $max && defined $min && $max < $min);
    die "Minimum value must be greater than maximun value ($symbol).\n\tmax: $max\n\tmin: $min\n" if ($symbol eq "-" && defined $max && defined $min && $min < $max);
  }

  sub equals{
    my ($self, $range) = @_;
    die "Only Range values allowed.\n" if (!defined $range || ref($range) ne "Range");
    return $self->getMax() == $range->getMax() && $self->getMin() == $range->getMin();
  }

  sub clone{
    my $self = shift;
    return new Range($self->{min}, $self->{max}, $self->getTrimDecimalFunction());
  }

  sub mutate{
    my $self = shift;
    my ($function) = @_;
    my ($min, $max) = $function->($self->getRawValues);
    return new Range($min, $max, $self->getTrimDecimalFunction);
  }

  sub toString{
    my $self = shift;
    return $self->{min} . " -> " . $self->{max};
  }

  sub toTextGrid{
    my ($self) = shift;
    return $self->getMin() . "\n" . $self->getMax();
  }

  1;
}

package Node{

  use strict;
  use warnings;
  
  sub new{
    my ($class, $value, $range) = @_;
    die "Only Range values allowed for range.\n" if (!defined $range || ref($range) ne "Range");
    $value =~ s/"{2}/"/g if (defined $value && ref $value eq "");
    return bless{
      value => $value,
      range => $range
    }, $class;
  }

  sub value{ return shift->getValue; }

  sub getValue{ return shift->{value}; }
  
  sub setValue{ my ($self, $value) = @_;
          $self->{value} = $value; }

  sub range{ return shift->getRange; }

  sub getRange{ return shift->{range}; }

  sub toString{
    my ($self, $toStringValueFunction) = @_;
    $toStringValueFunction = sub{ return shift->getValue(); } if (!defined $toStringValueFunction);
    die "Only CODE values allowed." if (!defined $toStringValueFunction || ref $toStringValueFunction ne "CODE");
    return "" if !defined $self->getRange()->toString();
    return "[" . $self->getRange()->toString() . "] " . $toStringValueFunction->($self);
  }

  sub toTextGrid{
    my ($self) = shift;
    my $val = $self->getValue();
    if (!defined $val){
      print "Undefined Value at ".$self->getRange->toString."\n";
      $val = "";
    }
    $val =~ s/"/""/g;
    return $self->getRange()->toTextGrid() . "\n\"" . $val . "\"";
  }

  sub clone{
    my $self = shift;
    my $ret = new Node($self->{value}, $self->{range}->clone());
  }

  sub equals{
    my ($self, $node) = @_;
    die "Only Node values allowed." if (!defined $node || ref $node ne "Node");
    return $self->getValue() eq $node->getValue() && $self->getRange()->equals($node->getRange());
  }
  
  #sub toStr{
  #  my $self = shift;
  #  return $self->getValue()." ".$self->getRange->getMin()." ".$self->getRange->getMax();
  #}

  use constant{ VOID => '*<{[(/VOID/)]}>*' };
  
  1;
}

package EvaluationRule{

  use strict;
  use warnings;
  
  sub new{
    my ($class, $valueCode, $code) = @_;
    $code = sub{ shift->getValue() ne shift->getValue(); } if (ref $code eq "" && $code eq "ne");
    $code = sub{ shift->getValue() eq shift->getValue(); } if (ref $code eq "" && $code eq "eq");
    die "Only CODE values allowed." if (ref $code ne "CODE");
    return bless{
      value => $valueCode,
      comparator => $code
    }, $class;
  }

  sub run{
    my ($self, @args) = @_;
    return $self->{comparator}->(@args);
  }

  sub runValue{
    my ($self, @args) = @_;
    return ref $self->{value} eq "CODE" ? $self->{value}->(@args) : $self->{value};
  }
  
  1;
}

package NodeChain{

  use strict;
  use warnings;
  use Data::Dump qw(dump);
  use utf8;
  use POSIX;
  use List::Util qw(none);
  use Scalar::Util qw(looks_like_number);

  sub new{
    my ($class, $name, $merging, $allow0Length, $trimDecimalFunction) = @_;
    $merging = 1 if (!defined $merging);
    die "The name must not be empty." if (!defined $name || $name =~ /^\s*$/);
    return bless{
      list => [],
      name => $name,
      merging => $merging,
      allow0Length => defined $allow0Length ? $allow0Length : 0,
      onNameChanged => sub{ return 1; },
      trimDecimalFunction => $trimDecimalFunction
    }, $class;
  }

  sub getChild{
    my ($self, $prefix) = @_;
    $prefix = "" if (!defined $prefix);
    return new NodeChain($prefix =~ /^-/ ? $self->getName() . $prefix : $prefix . $self->getName(), $self->{merging}, $self->{allow0Length}, $self->getTrimDecimalFunction());
  }

  sub getTrimDecimalFunction{ return shift->{trimDecimalFunction}; }

  sub setTrimDecimalFunction{
    my $self = shift;
    my ($trimDecimalFunction) = @_;
    $self->{trimDecimalFunction} = $trimDecimalFunction;
    return $self;
  }

  sub getList{ return shift->{list}; }

  sub getName{ return shift->{name}; }

  sub setZeroLengthPermission{
    my ($self, $permission) = @_;
    die "Not defined permission." if (!defined $permission);
    $self->{allow0Length} = $permission;
    return $self;
  }

  sub setName{
    my ($self, $name) = @_;
    my $oldName = $self->{name};
    $self->{name} = $name;
    $self->{onNameChanged}->($oldName, $self->{name});
    return $self;
  }

  sub setOnNameChanged{
    my ($self, $sub) = @_;
    die "Only CODE values allowed." if (!defined $sub || ref $sub ne "CODE");
    $self->{onNameChanged} = $sub;
  }

  sub queryNodeIndex{
    my ($self, $node) = @_;
    my $index = $self->queryAnIndex($node->getRange());
    return -1 if ($index >= @{$self->getList()});
    return $self->getNodeAt($index)->equals($node) ? $index : -1;
  }

  sub queryAnIndex{
    my ($self, $range) = @_;
    die "Only Range values allowed." if (!defined $range || ref $range ne "Range");
    my @list = @{$self->getList()};
    my $izq = 0;
    my $der = @list - 1;
    return $izq if $der < 0 || float_le($range->getMin(), $list[$izq]->getRange()->getMin());
    return $der if float_ge($range->getMin(), $list[$der]->getRange()->getMin());
    my $mid = undef;
    my $midGeter = sub{
      return POSIX::floor(($izq + $der) / 2) if (!defined $mid || $izq != $der - 1);
      return $izq if ($izq == $der - 1 && $mid == $der);
      return $der;
    };
    $mid = $midGeter->();
    while ($izq != $der){
      my $midRange = $list[$mid]->getRange();
      last if float_ge($range->getMin(), $midRange->getMin()) && float_lt($range->getMin(), $midRange->getMax());
      last if float_ge($range->getMin(), $midRange->getMax()) && $mid < @list - 1 && float_lt($range->getMin(), $list[$mid + 1]->getRange()->getMin());
      $izq = $mid if float_le($list[$mid]->getRange()->getMin(), $range->getMin());
      $der = $mid if float_ge($list[$mid]->getRange()->getMin(), $range->getMin());
      $mid = $midGeter->();
    }
    return $mid;
  }

  sub addNodesWithoutChecking{
    my ($self, @nodes) = @_;
    @nodes = @{$nodes[0]->{list}} if (@nodes == 1 && ref $nodes[0] eq "NodeChain");
    $self->clear();
    @{$self->{list}} = @nodes;
    return $self;
  }
  
  sub addNodes{
    my ($self, @nodes) = @_;
    my $list = $self->{list};
    @nodes = @{$nodes[0]->{list}} if (@nodes == 1 && ref $nodes[0] eq "NodeChain");
    my $nodeCount = 0;
    foreach my $currNode (@nodes){
      die "Only Node values allowed.\n" if ref($currNode) ne "Node";

      my $ucNode = new Node($currNode->getValue(), new Range($currNode->getRange()->getMin(), $currNode->getRange()->getMax(), $self->getTrimDecimalFunction()));

      my $index = $self->queryAnIndex($ucNode->getRange());

      $index++ while (@$list > 0 && $index < @$list && float_le($list->[$index]->getRange()->getMin(), $ucNode->getRange()->getMin()) && float_le($list->[$index]->getRange()->getMax(), $ucNode->getRange()->getMin()));

      if (@$list > 0 && $index < @$list && float_lt($list->[$index]->getRange()->getMin(), $ucNode->getRange()->getMin())){ # Changed Santy's float_le
        my $tempNode = new Node($list->[$index]->getValue(), new Range($list->[$index]->getRange()->getMin(), $ucNode->getRange()->getMin(), $self->getTrimDecimalFunction()));
        splice(@$list, $index++, 0, $tempNode); # if $self->{allow0Length} || float_ne($tempNode->getRange()->getDiff(), 0); # The above change prevents Santy's zero length node insertion
      }

      splice(@$list, $index, 1) while (@$list > 0 && $index < @$list && float_ge($ucNode->getRange()->getMax(), $list->[$index]->getRange()->getMax()));

      if (@$list > 0 && $index < @$list && float_le($list->[$index]->getRange()->getMin(), $ucNode->getRange()->getMax())){
        $list->[$index]->getRange()->setMin($ucNode->getRange()->getMax());
        splice(@$list, $index, 1) if float_eq($list->[$index]->getRange()->getDiff(), 0); # Deletes the $index node when it reaches zero length
      }

      splice(@$list, $index, 0, $ucNode) if float_ne($ucNode->getRange()->getDiff(), 0); # $self->{allow0Length} || # Do not allow Santy's zero length node insertion.
    }
    $self->merge() if ($self->{merging});
    return $self;
  }

  sub moveTo{
    my ($self, $stamp) = @_;
    return $self->count ? $self->moveBy($stamp - $self->getFirstNode()->getRange()->getMin()) : $self;
  }

  sub moveBy{
    my ($self, $lapse) = @_;
    my $ret;
    if ($lapse == 0){
      $ret = $self->clone();
      $ret->setName("moved-" . $self->getName());
    }
    else{
      $ret = $self->getChild("moved-");
      if ($self->count){
        $ret->addNodes(new Node($_->getValue(), $_->getRange()->getACopyMovedBy($lapse))) foreach (@{$self->getList()});
      }
    }
    return $ret;
  }

  sub scale{
    my ($self, $factor) = @_;
    $_->getRange()->scale($factor) foreach (@{$self->getList()});
    return $self;
  }
  
  # Josafa
  sub float_eq{ abs($_[0] - $_[1]) < ($_[2] //= 1e-9) }
  sub float_ne{ abs($_[0] - $_[1]) >= ($_[2] //= 1e-9) }
  sub float_lt{ ($_[0] < $_[1]) && !float_eq($_[0], $_[1], ($_[2] //= 1e-9)) }
  sub float_le{ ($_[0] < $_[1]) || float_eq($_[0], $_[1], ($_[2] //= 1e-9)) }
  sub float_gt{ ($_[0] > $_[1]) && !float_eq($_[0], $_[1], ($_[2] //= 1e-9)) }
  sub float_ge{ ($_[0] > $_[1]) || float_eq($_[0], $_[1], ($_[2] //= 1e-9)) }

  sub getContentWithin{
    my ($self, $range, $condition, $cut) = @_;

    $range = $range->getBounds() if (ref $range eq "NodeChain");
    die "Only Range values allowed." if (!defined $range || ref $range ne "Range");

    $condition = sub{ return 1; } if (!defined $condition);
    $cut = 1 if (!defined $cut);

    my $list = $self->{list};
    my @retNodes;

    my $index = $self->queryAnIndex($range);

    $index++ while (@$list > 0 && $index < @$list && float_le($list->[$index]->getRange()->getMin(), $range->getMin()) && float_le($list->[$index]->getRange()->getMax(), $range->getMin()));

    if (@$list > 0 && $index < @$list && float_le($list->[$index]->getRange()->getMin(), $range->getMin())){
      my $max;
      if (float_le($range->getMax(), $list->[$index]->getRange()->getMax())){ $max = $cut ? $range->getMax() : $list->[$index]->getRange()->getMax(); }
      else{ $max = $list->[$index]->getRange()->getMax(); }

      my $min = $cut ? $range->getMin() : $list->[$index]->getRange()->getMin();
      my $tempNode = new Node($list->[$index]->getValue(), new Range($min, $max, $self->getTrimDecimalFunction));
      push @retNodes, $tempNode if ($self->{allow0Length} || $tempNode->getRange->getDiff != 0) && $condition->($tempNode);
      $index++;
    }

    while (@$list > 0 && $index < @$list && float_ge($range->getMax(), $list->[$index]->getRange()->getMax())){
      my $tempNode = $list->[$index++]->clone();
      push @retNodes, $tempNode if ($self->{allow0Length} || float_ne($tempNode->getRange->getDiff, 0)) && $condition->($tempNode);
    }
    
    if (@$list > 0 && $index < @$list && float_lt($list->[$index]->getRange()->getMin(), $range->getMax())){
      my $max = $cut ? $range->getMax() : $list->[$index]->getRange()->getMax();
      my $tempNode = new Node($list->[$index]->getValue(), new Range($list->[$index]->getRange()->getMin(), $max, $self->getTrimDecimalFunction));
      push @retNodes, $tempNode if ($self->{allow0Length} || float_ne($tempNode->getRange->getDiff, 0)) && $condition->($tempNode);
    }

    return $self->getChild("sub-")->addNodesWithoutChecking(@retNodes);
  }

  sub groupAsValues{
    my ($self, $toStringFunction) = @_;
    $toStringFunction = sub{ return shift } if (!defined $toStringFunction);
    die "Only CODE values allowed." if (ref $toStringFunction ne "CODE");
    return $self->groupAs(sub{ return $toStringFunction->(shift->getValue()); })
  }

  sub groupAs{
    my ($self, $function) = @_;
    die "Only CODE values allowed." if (!defined $function || ref $function ne "CODE");
    my %ret;
    foreach my $node (@{$self->getList()}){
      my $tempNode = $node->clone();
      my $t = $function->($tempNode);
      die "Undefined group. Perhaps the grouping function did not return any value.\n" if (!defined $t);
      $ret{$t} = new NodeChain($t) if (!exists $ret{$t});
      $ret{$t}->addNodes($tempNode);
    }
    return %ret;
  }

  sub select{
    my ($self, $selectionCode) = @_;
    my @indexes = $self->getNodeIndexes($selectionCode);
    my $ret = $self->getChild("sel-");
    $ret->addNodes(@{$self->getList()}[$_]->clone()) foreach @indexes;
    return $ret;
  }

  sub getRanges{
    my ($self, $selectionCode) = @_;
    my @ret;
    push @ret, $_->getRange for @{$self->select($selectionCode)->getList};
    return @ret;
  }

  sub getNodeIndexes{
    my ($self, $condition) = @_;
    my @ret;
    for (my $i = 0; $i < @{$self->getList()}; $i++){ push @ret, $i if ($condition->(@{$self->getList()}[$i]->clone())); }
    return @ret;
  }

  sub merge{
    my ($self, $start) = @_;
    my $list = $self->{list};
    $start = 0;
    die "Index must be a positive number.\n" if ($start < 0);
    if (@$list){
      if ($start >= @$list){
        die "Index ($start) greater than the number of elements in the list (" . @$list . ").\n";
      }
      while ($start < @{$self->getList()}){
        my $index = $start++;
        while ($index < $#$list &&
             $list->[$index + 1]->getRange()->getMin() == $list->[$index]->getRange()->getMax() &&
             $list->[$index + 1]->getValue() eq $list->[$index]->getValue()){
          $list->[$index]->getRange()->setMax($list->[$index + 1]->getRange()->getMax());
          splice (@$list, $index + 1, 1);
        }
        print "";
      }
    }
    return $self;
  }

  # Josafa
  sub applyMerge{
    my ($self, %args) = (splice(@_, 0, 1), start => 0, num_nodes => 2, reject => '', separator => '', speech_range => undef, @_);
    while ($args{num_nodes} > 1){
      $self->getNodeAt($args{start}, 0)->getRange->setMax($self->getNodeAt($args{start} + 1)->getRange()->getMax());
      my @new_values = ($self->getNodeAt($args{start})->getValue(), $self->getNodeAt($args{start} + 1)->getValue());
      if (none{$_ =~ m/^($args{reject})$/} @new_values){
      $self->getNodeAt($args{start}, 0)->setValue(join $args{separator}, @new_values);
      }
      splice (@{$self->{list}}, $args{start} + 1, 1);
      $args{num_nodes}--;
    }
  }
  
  # Josafa
  sub applyMerge2{
    my ($self, %args) = (splice(@_, 0, 1), start => 0, num_nodes => 2, reject => '', separator => '', speech_range => undef, @_);
    
    my ($new_value, $short_lduration, $threshold) = ('', 0);
    while ($self->getNodeAt($args{start})->getRange()->getMax() <= $args{speech_range}->getMin()){
      if ($self->getNodeAt($args{start})->getValue() !~ m/^($args{reject})$/){
      $new_value .= $self->getNodeAt($args{start})->getValue();
      $short_lduration += $self->getNodeAt($args{start})->getRange->getDuration;
      }
      $threshold = $self->getNodeAt($args{start} -1, 0)->getRange->getMax();
      $self->getNodeAt($args{start} -1, 0)->getRange->setMax($self->getNodeAt($args{start})->getRange()->getMax());
      splice (@{$self->{list}}, $args{start}, 1);
      $args{num_nodes}--;
    }
    
    $threshold = $args{speech_range}->getMin() - $threshold;
    if ($self->getNodeAt($args{start})->getRange()->getMin() == $args{speech_range}->getMin() &&
      $self->getNodeAt($args{start})->getRange()->getMax() == $args{speech_range}->getMax()){ # speech segment already exists
      my @new_values = ($new_value, $self->getNodeAt($args{start})->getValue());
      $self->getNodeAt($args{start}, 0)->setValue(join $args{separator}, @new_values);
      printf "Merging '%s' having duration: %0.2f located %0.2f away from range: %s => %s.\n", join (' + ', @new_values), $short_lduration, $threshold, $args{speech_range}->getMin(), $args{speech_range}->getMax();
    }else{ # Speech segment must be replicated in ipu tier.
      $self->getNodeAt($args{start} -1, 0)->getRange->setMax($args{speech_range}->getMin());
      if ($self->getNodeAt($args{start})->getRange->getMax() > $args{speech_range}->getMax()){
		my $new_node = new Node($new_value, $args{speech_range});
		splice (@{$self->{list}}, $args{start}, 0, $new_node); # Insertion
		$self->getNodeAt($args{start} + 1, 0)->getRange->setMin($args{speech_range}->getMax());
		printf "Replicate missing speech segment '%s' having duration: %0.2f located %0.2f away from range: %s => %s.\n", $new_value, $short_lduration, $threshold, $args{speech_range}->getMin(), $args{speech_range}->getMax();
      }
    }
  }
  
  # Josafa
  sub trimLeftRight{
    my ($self, $delete) = @_;
    unless ($delete){
      printf STDERR "Parameter 'delete' from function trimLeftRight must be no empty.\n";
      return;
    }
      
	splice(@{$self->getList}, 0, 1) if $self->getFirstNode->getValue eq $delete;
	my $num_nodes = $self->count;
	splice(@{$self->getList}, --$num_nodes, 1) if $num_nodes > 0 && $self->getLastNode->getValue eq $delete;
    
    return $self;
  }

  sub getBounds{
    my $self = shift;
    my $list = $self->{list};
    my $max = @$list - 1;
    return undef if ($max < 0);
    return new Range($list->[0]->getRange()->getMin(), $list->[$max]->getRange()->getMax());
  }

  sub fill{
    my ($self, $value, $range) = @_;
    $value = "" if (!defined $value);
    if (!defined $range){
      my $list = $self->{list};
      my $cont = 1;
      while ($cont < @$list){
        splice(@$list, $cont, 0, new Node($value, new Range($list->[$cont - 1]->getRange()->getMax(), $list->[$cont]->getRange()->getMin()))) if ($list->[$cont - 1]->getRange()->getMax() < $list->[$cont]->getRange()->getMin());
        $cont++;
      }
    }
    else{
      die "Only Range values allowed." if (ref $range ne "Range");
      my $maskText = "text";
      my $tofill;
      if (!@{$self->getList()} || ($range->getMin() <= $self->getBounds()->getMin() && $range->getMax() >= $self->getBounds()->getMax())){ $tofill = $self->clone(); }
      else{ $tofill = $self->getContentWithin($range); }
      $tofill = $tofill->maskAsFunction(sub{ return $maskText; });
      my $base = new NodeChain("base");
      $base->addNodes(new Node($maskText, $range));
      my $comparison = $base->compare($tofill, [new EvaluationRule("empty", "ne")])->select(sub{ return shift->getValue() eq "empty"; })->maskAsFunction(sub{ return $value; });
      $self->addNodes($comparison);
    }
    $self->merge() if ($self->{merging});
    return $self;
  }

  sub extendRight{
    my $self = shift;
    my $list = $self->{list};
    for (my $i = 0; $i < @$list - 1; $i++){
      if ($list->[$i]->getRange()->getMax() < $list->[$i + 1]->getRange()->getMin()){
        $list->[$i]->getRange()->setMax($list->[$i + 1]->getRange()->getMin());
      }
    }
    $self->merge() if ($self->{merging});
    return $self;
  }

  sub extendLeft{ die "Not yet implemented."; }

  sub count{ return scalar @{shift->{list}}; }

  sub nodeAt{
    my $self = shift;
    my ($index, $safe) = @_;
    return $self->getNodeAt($index, $safe);
  }

  sub getNodeAt{
    my ($self, $index, $safe) = @_;
    $safe = 1 unless defined $safe;
    die "Index must be a positive number.\n" if (!defined $index || $index < 0);
    if ($index >= scalar(@{$self->{list}})){
      die "Index ($index) greater than the number of elements in the list (" . scalar(@{$self->{list}}) . ").\n";
    }
    my $ret = $self->{list}->[$index];
    return $safe ? $ret->clone() : $ret;
  }

  sub getLastNode{
    my ($self, $safe) = @_;
    print "Method getLastNode requires a tier to have at least one node.\n" if $self->count() < 1;#Josafa
    return $self->getNodeAt($self->count() - 1, $safe);
  }

  sub getFirstNode{
    my ($self, $safe) = @_;
    return $self->getNodeAt(0, $safe);
  }
  
  #Josafa
  sub getLongestNode{
    my ($self, $safe) = @_;
    my ($dur, $node_dur, $longestNode) = 0;
    for my $node (@{$self->getList()}){
      $node_dur = $node->getRange->getDiff();
      if ($node_dur > $dur){
       $longestNode = $node;
       $dur = $node_dur;
      }
    }
    return $longestNode;
  }
  
  #Josafa
  sub getLastNodeByValue{
    my ($self, $value, $safe) = @_;
    my $longestNode;
    for my $node (@{$self->getList()}){
      $longestNode = $node if $node->getValue() eq $value;
    }
    unless ($longestNode){
      printf "There's no such node value: '%s' within the given nodes starting from %s.\n", $value, dump($self->getNodeAt(0)->toString());
      return;
    }
    return $safe ? $longestNode->clone() : $longestNode;
  }

  sub print{
    my ($self, $tier) = @_;
    for (my $i=0; $i < $self->count(); $i++){
      my $node = $self->getNodeAt($i);
      
        print $node->getValue()." ".$node->getRange->getMin()." ".$node->getRange->getMax()."\n";
    }
    print "\n";
    return 0;
  }
  
  sub toTextGrid{
    my ($self) = shift;
    my $length = $self->getNodeAt($self->count() - 1)->getRange()->getMax();
    my $ret = "\"IntervalTier\"\n";
    $ret .= "\"" . $self->{name} . "\"\n";
    $ret .= $self->getNodeAt(0)->getRange()->getMin() . "\n";
    $ret .= $self->getNodeAt($self->count() - 1)->getRange()->getMax() . "\n";
    $ret .= $self->count() . "\n";
    foreach my $node (@{$self->getList()}){ $ret .= $node->toTextGrid() . "\n"; }
    $ret =~ s/\s+$//;
    return $ret;
  }

  sub compare{
    my ($self, $a, $evaluationRules) = @_;
    die "Only NodeChain values allowed." if (!defined $a || ref $a ne "NodeChain");
    $evaluationRules = [$evaluationRules] if (defined $evaluationRules && ref $evaluationRules ne "ARRAY");
    die "No comparison rules provided." if (!@{$evaluationRules});

    my $ret = new NodeChain("diff-" . $self->{name} . "_" . $a->{name});
    return $ret if (!defined $self->getBounds() && !defined $a->getBounds());

    my $minMaxBoundGetter = sub{
      my ($tierA, $tierB) = @_;
      my $ABounds = $tierA->getBounds();
      my $BBounds = $tierB->getBounds();
      if (!defined $ABounds){
        return $BBounds;
      }
      elsif (!defined $BBounds){
        return $ABounds;
      }
      else{
        my $tierAMin = $ABounds->getMin();
        my $tierAMax = $ABounds->getMax();
        my $tierBMin = $BBounds->getMin();
        my $tierBMax = $BBounds->getMax();
        return new Range($tierAMin < $tierBMin ? $tierAMin : $tierBMin, $tierAMax > $tierBMax ? $tierAMax : $tierBMax);
      }
    };

    my $base = new NodeChain("base-" . $self->{name});
    $base->addNodes(new Node(Node->VOID, $minMaxBoundGetter->($self, $a)));
    $base->addNodes($self->clone());
    my $trg = new NodeChain("base-" . $a->{name});
    $trg->addNodes(new Node(Node->VOID, $base->getBounds()));
    $trg->addNodes($a->clone());

    #$ret->addNodes(new Node("", $base->getBounds()));

    foreach my $node (@{$base->getList()}){
      my $c = $trg->getContentWithin($node->getRange());
      foreach my $n (@{$c->getList()}){
        foreach my $comparisonRule (@{$evaluationRules}){
          die "Only EvaluationRule values allowed." if (ref $comparisonRule ne "EvaluationRule");
          if ($comparisonRule->run($node, $n)){
            $ret->addNodes(new Node($comparisonRule->runValue($node->getValue(), $n->getValue()), $n->getRange()->clone()));
            last;
          }
        }
      }
    }
    return $ret;
  }

  sub getAllValuesAsString{
    my ($self, $sep, $stringConvertionFunction) = @_;
    $stringConvertionFunction = sub{ return shift->getValue(); } if (!defined $stringConvertionFunction);
    $sep = "" if (!defined $sep);
    my $ret = "";
    my @list = @{$self->getList()};
    for (my $i = 0; $i < @list; $i++){
      $ret .= $stringConvertionFunction->($list[$i]->clone());
      $ret .= $sep if ($i < @list - 1);
    }
    return $ret
  }

  sub maskAsNumber{
    my ($self, $start) = @_;
    $start = 0 if (!defined $start || $start =~ /^\s*$/);
    my $i = $start;
    return $self->maskAsFunction(sub{ return $i++; });
  }

  sub maskAsFunction{
    my ($self, $maskFunction) = @_;
    die "Only CODE values allowed." if (!defined $maskFunction || ref $maskFunction ne "CODE");
    my $ret = $self->getChild("mask-");
    $ret->addNodes(new Node($maskFunction->($_), $_->getRange()->clone())) foreach (@{$self->getList()});
    return $ret;
  }

  sub yieldAllNodes{
    my ($self, $function) = @_;
    return $self->yieldNodesByIndex($function, 0 .. $self->count() - 1);
  }

  sub backYieldAllNodes{
    my ($self, $function) = @_;
    my @arr;
    my $i = $self->count() - 1;
    push @arr, $i-- while ($i >= 0);
    return $self->yieldNodesByIndex($function, @arr);
  }

  sub yieldNodesByIndex{
    my ($self, $function, @indexes) = @_;
    die "Only CODE values allowed." if (!defined $function || ref $function ne "CODE");
    foreach my $i (@indexes){
      die "No node at index $i." if ($i < 0 || $i >= $self->count());
      my $last = $function->($i, @{$self->{list}}[$i]);
      last if looks_like_number($last) && $last == 1;
    }
    return $self;
  }

  sub toString{
    my ($self, $toStringValueFunction) = @_;
    my $cont = 0;
    my $ret = $self->{name} . ":\n";
    foreach my $node (@{$self->{list}}){ $ret .= $cont++ . ": " . $node->toString($toStringValueFunction) . "\n"; }
    $ret =~ s/\n+$//;
    return $ret;
  }
  
  sub clone{
    my $self = shift;
    my $ret = $self->getChild();
    push @{$ret->{list}}, $_->clone() foreach (@{$self->{list}});
    return $ret;
  }

  sub clear{
    my $self = shift;
    @{$self->{list}} = ();
    return $self;
  }

  sub getNonVoidRanges{
    my $self = shift;
    my @ret;
    push @ret, $_->getRange()->clone() foreach (@{$self->getList()});
    return @ret;
  }

  #sub crc{
  #  my ($self, $val) = @_;
  #  return Digest::CRC::crc32($self->toString);
  #}

  sub getCommonStamps{
    my $self = shift;
    my @ret;
    my $lastStamp = undef;
    $self->yieldAllNodes(sub{
      my ($i, $n) = @_;
      push @ret, $lastStamp if defined $lastStamp && $lastStamp == $n->range->min;
      $lastStamp = $n->range->max;
      return 0;
    });
    return @ret;
  }
  
  1;
}

package TextGrid{

  # Version 1.0 20250625
  use strict;
  use warnings;
  use Encode;
  use utf8;
  use Scalar::Util qw(looks_like_number);
  use Exporter 'import';
  our $trimDecimal = sub{ return 0 + sprintf "%.3f", shift; };
  our @EXPORT_OK = qw(read_file write_file float_eq float_ne float_lt float_le float_gt float_ge $trimDecimal);

  binmode(STDOUT, ":encoding(UTF-8)");
  binmode(STDIN,  ":encoding(UTF-8)");

  sub new{
    my ($class, $txtg, $intervalTrimFunction, $tiersToReadFunction) = @_;
    $intervalTrimFunction = sub{ return shift, shift; } if (!defined $intervalTrimFunction);
    $tiersToReadFunction  = sub{ return 1; } if (!defined $tiersToReadFunction);
    die "Only CODE values allowed for `intervalTrimFunction`." if (ref $intervalTrimFunction ne "CODE");
    die "Only CODE values allowed for `tiersToReadFunction`." if (ref $tiersToReadFunction ne "CODE");
    my $self = bless{
      fileType             => "ooTextFile",
      objectClass          => "TextGrid",
      tiers                => {},
      tierIndex            => [],
      filePath             => undef,
      intervalTrimFunction => $intervalTrimFunction,
      tiersToRead          => $tiersToReadFunction,
      warnings             => [],
      onTierNameChanged    => undef
    }, $class;
    $self->{onTierNameChanged} = sub{
      my ($oldName, $newName) = @_;
      die "The name of the `$oldName` tier cannot be changed to `$newName` since there is already another one with that name.\n" if ($self->containsTier($newName));
      my $changed = 0;
      for (my $i = 0; $i < @{$self->{tierIndex}}; $i++){
        my $chainName = @{$self->{tierIndex}}[$i];
        next if ($chainName ne $oldName);
        @{$self->{tierIndex}}[$i] = $newName;
        $changed = 1;
        last;
      }
      die "No tier named `$oldName` found.\n" if (!$changed);
      $self->{tiers}{$newName} = delete $self->{tiers}{$oldName};
    };
    $self->read($txtg) if (defined $txtg);
    return $self;
  }

  sub count{
    my $r = keys %{shift->{tiers}};
    return $r;
  }

  sub containsWarnings{ return @{shift->{warnings}}; }

  sub setTiersToReadfunction{
    my ($self, $function) = @_;
    die "Only CODE values allowed for `function`." if (!defined $function || ref $function ne "CODE");
    $self->{tiersToRead} = $function;
  }

  sub isTierToRead{
    my ($self, $tierName) = @_;
    return $self->{tiersToRead}->($tierName);
  }

  sub getTier{
    my ($self, $name) = @_;
    die "There is no tier named '$name'.\n" if (!$self->containsTier($name));
    return $self->{tiers}{$name};
  }

  sub yieldTiers{
    my ($self, $function) = @_;
    die "Only CODE values allowed for `function`." if (!defined $function || ref $function ne "CODE");
    $function->($self->getTier($_)) foreach ($self->getTierNames());
    return $self;
  }

  sub addWarning{
    my ($self, $text) = @_;
    push @{$self->{warnings}}, $text;
  }

  sub getTierNames{ return @{shift->{tierIndex}}; }

  sub getBaseFile{ return @{shift->{filePath}}; }

  sub containsTier{
    my ($self, $name) = @_;
    return exists $self->{tiers}{$name};
  }

  sub printWarnings{
    my ($self) = @_;
    my $ret = defined $self->{fileType} ? $self->{fileType} . "\n" : "";
    $ret .= $_ . "\n" foreach (@{$self->{warnings}});
    $ret =~ s/^\s+|\s+$//g;
    return $ret;
  }

  sub scale{
    my $self = shift;
    my ($factor) = @_;
    return $self->yieldTiers(sub{ shift->scale($factor); });
  }

  sub merge{
    my $self = shift;
    my ($factor) = @_;
    return $self->yieldTiers(sub{ shift->merge; });
  }

  sub fill{
    my $self = shift;
    my ($value, $range) = @_;
    return $self->yieldTiers(sub{ shift->fill($value, $range); });
  }

  sub read{
    my ($self, $txtg) = @_;
    die "Empty .TextGrid string.\nProvide a path to a .TextGrid file or the text content of the file.\n" if (!defined $txtg || $txtg =~ /^\s*$/);
    my $textContent = "";
    if (-e $txtg){
      eval{ $textContent = read_file($txtg); };
      die "Error while building TextGrid object.\n$@\n" if $@;
      $self->{filePath} = $txtg;
    }
    else{ $textContent = $txtg; }
    $self->readTextGrid($textContent);
  }

  sub runIntervalTrim{
    my ($self, @args) = @_;
    my ($min, $max) = $self->{intervalTrimFunction}->(@args);
    die "Trim error.\nMin value seems not to be a number: $min\nOriginal Min: " . $args[0] . "\n" if !looks_like_number($min);
    die "Trim error.\nMax value seems not to be a number: $max\nOriginal Max: " . $args[1] . "\n" if !looks_like_number($max);
    return $min + 0, $max + 0;
  }

  sub longTextGridCleaner{
    my ($self, $txt) = @_;
    $txt =~ s/^\s*File\s*type\s*=\s*/<ft>/i;
    $txt =~ s/^(\s*<ft>[^\s]+\s*)Object\s*class\s*=\s*/$1<og>/i;
    $txt =~ s/^\s*[^"\n]*?://gm;
    $txt =~ s/^\s*[^"\n]*?[?=]\s*//gm;
    $txt =~ s/^<ft>/File type = /i;
    $txt =~ s/(File\s*type\s*=\s*[^\s]*\s*)<og>/$1Object class = /i;
    return $txt;
  }

  sub readTextGrid{
    my ($self, $textContent) = @_;
    $textContent =~ s/\r//g;
    #die "Only short-text TextGrid format allowed. The provided content seems to be in long-text format." if ($textContent =~ /File\s*?type.*?Object\s*?class.*?xmin.*?xmax.*?tiers\?.*?size/si);
    $textContent = $self->longTextGridCleaner($textContent) if ($textContent =~ /File\s*?type.*?Object\s*?class.*?xmin.*?xmax.*?tiers\?.*?size/si);
    my $tierCount = -1;
    my $start = -1;
    my $end = -1;
    my $number = qr/\d+(?:\.\d+)?/;
    my $header = qr/^.*?File\s+type\s*\=\s*"(.+)?"\s*Object\s+class\s*\=\s*"(.+)?"\s*($number)\s*($number)\s*<exists>\s*($number)\s*/;
    my $intervals = qr/(?:($number)\s*($number)\s*"((?:"{2}|[^\n]*?\n*?)+)"\s*)/;
    my $tier = qr/^\s*"(.*)?"\s*"(.*)?"\s*($number)\s*($number)\s*($number)\s*($intervals+)/;
    if ($textContent =~ /$header/i){
      $self->{fileType} = $1;
      $self->{objectClass} = $2;
      ($start, $end) = $self->runIntervalTrim($3, $4);
      $tierCount = $5;
      $textContent =~ s/$header//i;
    }
    else{ die "Not a valid .TextGrid string.\n"; }

    while ($textContent =~ /$tier/){
      my $tierType = $1;
      my $tierName = $2;
      my $minMark = $3;
      my $maxMark = $4;
      my $intervalCount = $5;
      my $intervalBlock = $6;
      if ($self->isTierToRead($tierName)){
        my ($tierStart, $tierEnd) = $self->runIntervalTrim($minMark, $maxMark);
        my $lastBound = 0;
        die "Not supported tier type '$tierType'.\n" if ($tierType !~ /^IntervalTier$/i);
        my $chain = new NodeChain($tierName, 0, 1);
        while ($intervalBlock =~ /$intervals/g){
          $self->addWarning("Error in `$tierName` tier. The end bound must be greater or equal to the beginning bound\nBeginning bound: $1\nEnd bound: $2") if ($1 > $2);
          $self->addWarning("The beginning and end boundaries are the same at $1 s in `$tierName` tier.\n") if ($1 == $2);
          $self->addWarning("An interval starting from $lastBound s was expected, but one starting from $1 s has been encountered in `$tierName` tier.\n") if ($1 < $lastBound);
          $chain->addNodes(new Node($3, new Range($self->runIntervalTrim($1, $2))));
          $lastBound = $2;
        }
        die "Number of intervals (" . $chain->count() . ") doesn't match the interval count ($intervalCount) for tier `$tierName`.\n" if ($intervalCount != $chain->count());
        $self->addTier($chain);
      }
      else{ $tierCount -= 1; }
      $textContent =~ s/$tier//;
    }

    die "Number of tiers (" . $tierCount . ") doesn't match the tier count (" . $self->count() . ").\n" if ($tierCount != $self->count());
    die "Error parsing the .TextGrid.\n" if ($textContent !~ /^\s*$/);
  }

  sub compare{
    my ($self, $a, $evaluationRules, @tiers) = @_;
    die "Only TextGrid objects allowed." if (!defined $a || ref $a ne "TextGrid");
    @tiers = @{$self->{tierIndex}} if (!@tiers);
    my $notes = "";
    my $ret = new TextGrid();
    foreach my $tier (@tiers){
      die "There is no tier named '$tier' in the reference.\n" if (!exists $self->{tiers}{$tier});
      if (!exists $a->{tiers}{$tier}){ $notes .= "There is no tier named '$tier' in the target.\n"; }
      else{
        my $diff = $self->{tiers}{$tier}->compare($a->{tiers}{$tier}, $evaluationRules);
        $ret->addTier($diff);
      }
    }
    return $notes, $ret;
  }

  sub addTiers{
    my ($self, @tiers) = @_;
    foreach my $chain (@tiers){
      if (ref $chain eq "TextGrid"){ $self->addTier($chain->{tiers}{$_}) foreach (@{$chain->{tierIndex}}); }
      else{
        die "Only NodeChain values allowed." if (!defined $chain || ref $chain ne "NodeChain");
        print STDERR "There is already a tier named '" . $chain->getName() . "' which is being replaced.\n" if (exists $self->{tiers}{$chain->getName()});
        $chain->setOnNameChanged($self->{onTierNameChanged});
        push @{$self->{tierIndex}}, $chain->getName() unless (exists $self->{tiers}{$chain->getName()});
        $self->{tiers}{$chain->getName()} = $chain;
      }
    }
    return $self;
  }

  sub addTier{
    my ($self, $chain) = @_;
    if (ref $chain eq "TextGrid"){
      $self->addTier($chain->{tiers}{$_}) foreach (@{$chain->{tierIndex}});
    }else{
      die "Only NodeChain values allowed." if (!defined $chain || ref $chain ne "NodeChain");
      print STDERR "There is already a tier named '" . $chain->getName() . "' which is being replaced.\n" if (exists $self->{tiers}{$chain->getName()});
      $chain->setOnNameChanged($self->{onTierNameChanged});
      push @{$self->{tierIndex}}, $chain->getName() unless (exists $self->{tiers}{$chain->getName()});
      $self->{tiers}{$chain->getName()} = $chain;
    }
    return $self;
  }

  sub delTiers{
    my ($self, @tier_names) = @_;
    foreach my $tier_name (@tier_names){
      if (!$self->containsTier($tier_name)){
        #print $tier_name." does not exist to be deleted.\n";
        next;
      }
      
      my $tier_index = 0;
      foreach my $curr_tier (@{$self->{tierIndex}}){
        if ($curr_tier =~ /^$tier_name$/){
          splice @{$self->{tierIndex}}, $tier_index, 1;
          delete $self->{tiers}{$tier_name};
          last;
        }
        $tier_index++;
      }
    }
    return $self;
  }
  
  sub addOrCreate{
    my $self = shift;
    my @tiers = @_;
    for my $chain (@tiers){
      if (ref $chain eq "TextGrid"){ $self->addOrCreate($chain->{tiers}{$_}) foreach (@{$chain->{tierIndex}}); }
      else{
        die "Only NodeChain values allowed." if (!defined $chain || ref $chain ne "NodeChain");
        if ($self->containsTier($chain->getName)){
          $self->getTier($chain->getName)->addNodes($chain);
        }
        else{
          $self->addTier($chain);
        }
      }
    }
    return $self;
  }

  sub getBounds{
    my ($self) = @_;
    die "TextGrid object contains no tiers.\n" . (defined $self->{filePath} ? "Path: '" . $self->{filePath} . "'\n" : "") if (!@{$self->{tierIndex}});
    my $min = undef;
    my $max = undef;
    foreach my $tierName (@{$self->{tierIndex}}){
      my $chainBounds = $self->{tiers}{$tierName}->getBounds();
      if (defined $chainBounds){
        $min = $chainBounds->getMin() if (!defined $min || $chainBounds->getMin() < $min);
        $max = $chainBounds->getMax() if (!defined $max || $chainBounds->getMax() > $max);
      }
    }
    return defined $max && defined $min ? new Range($min, $max) : undef;
  }

  sub flash{
    my ($self, $filepath, $encoding) = @_;
    $filepath = $self->{filePath} if (!defined $filepath);
    die "File path not set.\n" if (!defined $filepath || $filepath =~ /^\s*$/);
    write_file($filepath, $self->toString(), encoding => $encoding);
    return $filepath;
  }

  sub toString{
    my ($self, @tiers) = @_;
    @tiers = @{$self->{tierIndex}} if (!@tiers);
    my $bounds = $self->getBounds();
    my $ret = "File type = \"" . $self->{fileType} . "\"\nObject class = \"" . $self->{objectClass} . "\"\n\n" . $bounds->getMin() . "\n" . $bounds->getMax() . "\n<exists>\n" . $self->count() . "\n";
    foreach my $i (@tiers){
      if ($self->containsTier($i)){
        my $tempTier = $self->{tiers}{$i}->clone();
        $tempTier->fill("", $bounds);
        $ret .= $tempTier->toTextGrid() . "\n";
      }
    }
    $ret =~ s/\s+$//;
    return $ret;
  }

  sub clone{
    my ($self) = @_;
    my $ret = new TextGrid(undef, $self->{intervalTrimFunction});
    $ret->{filePath} = $self->{filePath};
    push @{$ret->{tierIndex}}, $_ foreach (@{$self->{tierIndex}});
    push @{$ret->{warnings}}, $_ foreach (@{$self->{warnings}});
    $ret->{tiers}{$_} = $self->getTier($_)->clone() foreach (@{$ret->{tierIndex}});
    return $ret;
  }

  #sub crc{
  #  my $self = shift;
  #  my $ret = "";
  #  $self->yieldTiers(sub{
  #    $ret .= shift->crc;
  #    return 0;
  #  });
  #  return Digest::CRC::crc32($ret);
  #}
  
  sub validate_textgrid_path{
    my ($self, $TextGrid_filepath) = @_;
    
    unless (isPathString($TextGrid_filepath)){
      print "File $TextGrid_filepath not found.\n";
      return 0;
    }
    my $TextGridMtg = new TextGrid($TextGrid_filepath, \&intervalTrimFunction, undef);
    return $TextGridMtg;
  }

  sub intervalTrimFunction{
    my ($min, $max) = @_;
    return $trimDecimal->($min), $trimDecimal->($max);
  }
  
  sub isPathString{
    my $str = shift;
    return 0 if ($^O =~ /win/i && length $str > 260 || $^O =~ /linux/i && length $str > 4096);
    $str .= " ";
    return $str =~ m/^(?:[\\\/]?(?:.+[\\\/])+[^\\\/]+|[^\n]+)$/;
  }
  
  sub read_file{
    my ($filepath, %args) = (shift, encoding => '', @_); # 'utf-8'
    
    local $/;
    eval{open (FILE, "<", $filepath)};
    if ($@){
      printf STDERR "Can't read file \"%s\" [%s]\n", $filepath, $!;
      return;
    }
    my $fileContent = <FILE>;
    close FILE;
    
    my $encoded = `file -i $filepath`;
    if ($args{encoding} eq 'utf-8'){
      eval { $fileContent = Encode::decode('utf-8', $fileContent, Encode::FB_CROAK); };
      $fileContent = Encode::decode("utf-16", $fileContent, Encode::FB_CROAK) if $@;
    }elsif ($args{encoding} !~ /^\s*$/){
      $fileContent = Encode::decode($args{encoding}, $fileContent, Encode::FB_CROAK);
    }if ($encoded =~ m/utf-16/){
      $fileContent = Encode::decode("utf-16", $fileContent, Encode::FB_CROAK)
    }
    
    return $fileContent;
  }
  
  sub write_file{ # 'utf-8'
    my($filepath, $content, %args) = (splice(@_, 0, 2), encoding => '', append => 0, extension => '', @_);
    
    $filepath = $args{extension} && $filepath =~ m/(.+?)\.[\w]+$/ ? "$1.$args{extension}" : $filepath ; # Replaces file extension
    eval{
      open (FILE, ($args{append} ? ">" : "") . ">:" . ( $args{encoding} ? encoding($args{encoding}) : ''), $filepath); 
    };
    if ($@){
      printf STDERR "Can't write file \"%s\" [%s]\n", $filepath, $!;
      return;
    }
    print FILE $content;
    close FILE;
    
    return $filepath;
  }
  
  # Josafa
  sub float_eq{ abs($_[0] - $_[1]) < ($_[2] //= 1e-9) }
  sub float_ne{ abs($_[0] - $_[1]) >= ($_[2] //= 1e-9) }
  sub float_lt{ ($_[0] < $_[1]) && !float_eq($_[0], $_[1], ($_[2] //= 1e-9)) }
  sub float_le{ ($_[0] < $_[1]) || float_eq($_[0], $_[1], ($_[2] //= 1e-9)) }
  sub float_gt{ ($_[0] > $_[1]) && !float_eq($_[0], $_[1], ($_[2] //= 1e-9)) }
  sub float_ge{ ($_[0] > $_[1]) || float_eq($_[0], $_[1], ($_[2] //= 1e-9)) }

  1;
}