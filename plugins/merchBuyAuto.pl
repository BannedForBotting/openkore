package merchBuyAuto;

use encoding 'utf8';
use Log qw(debug warning error);
use Misc qw(getNPCInfo offlineMode);
use Globals qw($char @chars %config %storage $field $conState $AI $AI_forcedOff %items_lut $messageSender %ai_v %timeout $taskManager);
use Utils qw(distance timeOut);
use Utils::DataStructures qw(findKeyString);
use AI;

Plugins::register("merchBuyAuto", "compra itens no mercador", \&unload);

my $hooks = Plugins::addHooks(
   ['AI_pre',\&loop,undef],
   ['packet/quit_response', \&fail, undef]
);

sub unload {
   Plugins::delHooks($hooks);
   undef $hooks;
}

my $args;
my $state;
my @sellItemsList;
my @getItemsList;


sub loop {

	# Disconnect
	
	if($conState == 1){
		if(AI::action eq "merchBuyAuto" || AI::action eq "storageAuto"){
			undef $args->{getItemAmount};
			undef $args->{buyItemAmount};
			undef $args->{sellItemAmount};
			undef $args->{addItemAmount};
			undef $state;
			$state->{start} = 1;
		}
	}
	
	if($conState == 5){
		if(AI::action eq "storageAuto" && defined($storage{opened}) && !defined($state->{start})) {
			for(my $i = 0; exists $config{"merchBuyAuto_$i"}; $i++) {
				next if (!$config{"merchBuyAuto_$i"} || !$config{"merchBuyAuto_$i"."_npc"} || $config{"merchBuyAuto_$i"."_disabled"});
				my $itemStorageIndex = getStorageIndex($config{"merchBuyAuto_$i"});
				if(($storage{$itemStorageIndex}{amount} < $config{"merchBuyAuto_$i"."_minAmount"} 
					&& getItemAmount($config{"merchBuyAuto_$i"}) < $config{"merchBuyAuto_$i"."_minAmount"})){
					warning "[merchBuyAuto] merchBuyAuto ativado: ".$config{"merchBuyAuto_$i"}." insuficiente.\n";
					$state->{start} = 1;
					last;
				}
			}
		}
		
		if(defined($state->{start}) && timeOut($timeout{ai_merchBuyAuto})){
			for(my $i = 0; exists $config{"merchBuyAuto_$i"}; $i++) {
				next if (!$config{"merchBuyAuto_$i"} || !$config{"merchBuyAuto_$i"."_npc"} || $config{"merchBuyAuto_$i"."_disabled"});
				if(getItemId($config{"merchBuyAuto_$i"})){
					my $itemStorageIndex = getStorageIndex($config{"merchBuyAuto_$i"});
					if($storage{$itemStorageIndex}{amount} < $config{"merchBuyAuto_$i"."_minAmount"}){
						
						# Precisa comprar itens
						# Setando variáveis

						$args->{index} = $i;
						$args->{item} = $config{"merchBuyAuto_$i"};
						$args->{maxAmount} = $config{"merchBuyAuto_$i"."_maxAmount"};
						$args->{weight} = $config{"merchBuyAuto_$i"."_weight"};
						$args->{slot} = $config{"merchBuyAuto_$i"."_char"};
						$args->{zeny} = $config{"merchBuyAuto_$i"."_zeny"};
						$args->{distance} = $config{"merchBuyAuto_$i"."_distance"};
						$args->{storage} = $config{"merchBuyAuto_$i"."_storage"};
						$args->{storageSteps} = $config{"merchBuyAuto_$i"."_storageSteps"};
						$args->{npc} = $config{"merchBuyAuto_$i"."_npc"};
						$args->{name} = $char->{name} if (!$args->{name});
						AI::queue("merchBuyAuto") if AI::action ne "merchBuyAuto";
						$state->{charselect} = 1;
						undef $state->{start};
						last;
					}
				}
			}
			$state->{finish} = 1 if(defined($state->{start}));
		}
		
		
		
		if(AI::action eq "merchBuyAuto"){
		
			if(defined($state->{charselect}) && $args->{slot} ne $config{char} && $char->{name} eq $args->{name}){
				$args->{char} = $config{char};
				$config{char} = $args->{slot};
				$messageSender->sendRestart(1);
				$state->{checkInventory} = 1;
				undef $state->{charselect};
			}
			elsif(defined($state->{charselect})){
				$state->{checkInventory} = 1;
				undef $state->{charselect};
			}
			
			if(defined($state->{finish}) && $args->{slot} eq $config{char} && $char->{name} ne $args->{name}){
				$config{char} = $args->{char};
				$messageSender->sendRestart(1);
				$state->{storageAuto} = 1;
				$args->{done} = 1;
				undef $state->{finish};
				
			}
			if(defined($state->{storageAuto}) && $char->{name} eq $args->{name}){
				warning "[merchBuyAuto] Continuando com o storageAuto.\n";
				AI::dequeue;
				undef $state;
			}
			
			if(defined($state->{checkInventory}) && $args->{slot} eq $config{char} 
				&& $char->{name} ne $args->{name}
				&& 	@{$char->inventory->getItems()} 
				&& timeOut($timeout{ai_merchBuyAuto})){
				
			
				if(($args->{addItemAmount} = getItemAmount($args->{item})) > 0){
					$state->{addStart} = $args->{item};
					$state->{route} = $args->{storage};
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{checkInventory};
				}
				else {
				
					@sellItemsList = getSellItems($args->{index});
					
					for(my $i; $i<@sellItemsList; $i++){
						debug "Item: ".$sellItemsList[$i]->{name}."\n";
						debug "Index: ".getInventoryIndex($sellItemsList[$i]->{name})."\n";
						
						if(defined(getInventoryIndex($sellItemsList[$i]->{name}))){
							$state->{route} = $args->{npc};
							$state->{sellStart} = $sellItemsList[$i]->{name};
							$timeout{ai_merchBuyAuto}{time} = time;
							undef $state->{checkInventory};
							last;
						}
					}
					$state->{checkZenys} = 1 if (!defined($state->{sellStart}));
					undef $state->{checkInventory};
				}
				
			}
			
			
			if(defined($state->{checkZenys}) && $args->{slot} eq $config{char} 
				&& $char->{name} ne $args->{name}
				&& 	@{$char->inventory->getItems()} 
				&& timeOut($timeout{ai_merchBuyAuto})){
			
				
				if($char->{zeny} >= $args->{zeny}){ 
					# Compra itens
					$state->{buyStart} = $args->{item};
					$state->{route} = $args->{npc};
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{checkZenys};
				
				}
				else{
					$state->{getStart} = 1;
					$state->{route} = $args->{storage};
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{checkZenys};
				}

			}
			
			if(defined($state->{route}) && timeOut($timeout{ai_merchBuyAuto})){
			
				$args->{route} = {};
				getNPCInfo($state->{route}, $args->{route});
				
				if(!defined($storage{opened}) && $args->{route}{ok}){ 
					# Calcula a rota
					ai_route($args->{route}{map}, $args->{route}{pos}{x}, $args->{route}{pos}{y},
						 attackOnRoute => 1,
						 distFromGoal => $args->{distance});
					warning "[merchBuyAuto] Calculando a rota para: ".$maps_lut{$args->{route}{map}.'.rsw'}."(".$args->{route}{map}."): ".$args->{route}{pos}{x}.", ".$args->{route}{pos}{y}."\n";
					$state->{distance} = 1;
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{route};
				}
				else {
					$messageSender->sendStorageClose();
					$timeout{ai_merchBuyAuto}{time} = time;
				}
			}
			
			
			if(defined($state->{distance}) && distance($args->{'npc'}{'pos'}, $chars[$config{'char'}]{'pos_to'}) 
				&& timeOut($timeout{ai_merchBuyAuto})){
				
				if(defined($state->{getStart})){
					# Pega
					
					ai_talkNPC($args->{route}{pos}{x}, $args->{route}{pos}{y}, $args->{storageSteps}) if (!defined($storage{opened}));
					for(my $i; $i<@sellItemsList; $i++){
						if(getStorageIndex($sellItemsList[$i]->{name})){
							$state->{getSent} = $sellItemsList[$i]->{name};
							$args->{getWeight} = $sellItemsList[$i]->{weight}
						}
					}
					
					if(defined($state->{getSent})){
						warning "[merchBuyAuto] Obtendo o item: ".$state->{getSent}."\n";
						$timeout{ai_merchBuyAuto}{time} = time;
						undef $state->{getStart};
						
					}
					elsif(!defined($state->{getSent}) && defined($storage{opened})){
						error "[merchBuyAuto] Não existem existem itens disponíveis para venda e os zenys são insuficientes para efetuar a compra de itens.\n";
						$config{"merchBuyAuto_$args->{index}_disabled"} = 1;
						undef $state;
						$state->{start} = 1;
					}
					$timeout{ai_merchBuyAuto}{time} = time;
				}
				elsif(defined($state->{buyStart}) && timeOut($timeout{ai_merchBuyAuto})){
					# Compra
					warning "[merchBuyAuto] Iniciando a compra do item: ".$state->{buyStart}."\n";
					ai_talkNPC($args->{route}{pos}{x}, $args->{route}{pos}{y}, 'b e');
					$state->{buySent} = $state->{buyStart};
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{buyStart};
				}
				elsif(defined($state->{sellStart}) && timeOut($timeout{ai_merchBuyAuto})){ 
					# Vende
					warning "[merchBuyAuto] Iniciando a venda do item: ".$state->{sellStart}."\n";
					ai_talkNPC($args->{route}{pos}{x}, $args->{route}{pos}{y}, 's e');
					$state->{sellSent} = $state->{sellStart};
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{sellStart};
				}
				elsif(defined($state->{addStart}) && timeOut($timeout{ai_merchBuyAuto})){
					# Armazena
					warning "[merchBuyAuto] Iniciando a armazenagem do item: ".$state->{addStart}."\n";
					ai_talkNPC($args->{route}{pos}{x}, $args->{route}{pos}{y}, $args->{storageSteps}) if (!defined($storage{opened}));
					$state->{addSent} = $state->{addStart};
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{addStart};				
				}
			}
			
			if(defined($state->{buySent}) && timeOut($timeout{ai_merchBuyAuto})){
				if($args->{retry} < 3){
					warning "[merchBuyAuto] Iniciando a compra do item: ".$state->{buySent}."\n";
					$args->{buyItemMaxWeight} = int(($char->{'weight_max'} - $char->{'weight'}) / $args->{weight});
					$args->{buyItemAmount} = ($args->{maxAmount} > $args->{buyItemMaxWeight}) ? $args->{buyItemMaxWeight} : $args->{maxAmount};
					$messageSender->sendBuyBulk([{itemID => getItemId($state->{buySent}), amount => $args->{buyItemAmount}}]);
					$state->{checkItem} = $state->{buySent};
					$args->{retry}++;
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{buySent};
				
				}
				else {
					error "[merchBuyAuto] Não consegui comprar o item [".$state->{buySent}."] em 3 tentativas.\n";
					error "[merchBuyAuto] Ajude na melhoria do plugin e reporte este erro.\n";
					undef $state->{buySent};
					undef $state->{checkItem};
					undef $state;
					offlineMode();
				}
				
			}
			
			if(defined($state->{sellSent}) && timeOut($timeout{ai_merchBuyAuto})){	

				if($args->{retry} < 3){
					$args->{sellItemIndex} = getItemInvSell($state->{sellSent});
					$args->{sellItemAmount} = getItemAmount($state->{sellSent});
					$messageSender->sendSellBulk([{index => $args->{sellItemIndex}, amount => $args->{sellItemAmount}}]);
					$state->{checkItem} = $state->{sellSent};
					$args->{retry}++;
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{sellSent};
				}
				else {
					error "[merchBuyAuto] Não consegui vender o item [".$state->{sellSent}."] em 3 tentativas.\n";
					error "[merchBuyAuto] Ajude na melhoria do plugin e reporte este erro.\n";
					undef $state->{sellSent};
					undef $state->{checkItem};
					undef $state;
					offlineMode();
				}
				
			}
			
			if(defined($state->{getSent}) && $storage{opened} && timeOut($timeout{ai_merchBuyAuto})){
			
				if($args->{retry} < 3){
					$args->{getItemIndex} = getStorageIndex($state->{getSent});
					$args->{getItemMaxWeight} = int(($char->{'weight_max'} - $char->{'weight'}) / $args->{getWeight});
					$args->{getItemAmount} = ($args->{getItemMaxWeight} <= $storage{$args->{getItemIndex}}{amount}) ? $args->{getItemMaxWeight} : $storage{$args->{getItemIndex}}{amount};
					$messageSender->sendStorageGet($args->{getItemIndex},$args->{getItemAmount});
					$state->{checkItem} = $state->{getSent};
					$args->{retry}++;
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{getSent};
				}
				else {
					error "[merchBuyAuto] Não consegui obter o item [".$state->{getSent}."] em 3 tentativas.\n";
					error "[merchBuyAuto] Ajude na melhoria do plugin e reporte este erro.\n";
					undef $state->{getSent};
					undef $state->{checkItem};
					undef $state;
					offlineMode();
				}	
			}
			
			if(defined($state->{addSent}) && $storage{opened} && timeOut($timeout{ai_merchBuyAuto})){
			
				if($args->{retry} < 3){
					$args->{addItemAmount} = getItemAmount($state->{addSent});
					$messageSender->sendStorageAdd((getItemInv($state->{addSent}), $args->{addItemAmount}));
					$timeout{ai_merchBuyAuto}{time} = time;
					$args->{retry}++;
					$state->{checkItem} = $state->{addSent};
					undef $state->{addSent};
				}
				else {
					error "[merchBuyAuto] Não armazenar obter o item [".$state->{addSent}."] em 3 tentativas.\n";
					error "[merchBuyAuto] Ajude na melhoria do plugin e reporte este erro.\n";
					undef $state->{addSent};
					undef $state->{checkItem};
					undef $state;
					offlineMode();
				}
				
			}
			
			if(defined($state->{checkItem}) && timeOut($timeout{ai_merchBuyAuto})){
			

				if((getItemAmount($state->{checkItem}) == $args->{getItemAmount}) && defined($args->{getItemAmount})){
					warning "[merchBuyAuto] O item [".$state->{checkItem}."] foi obtido com sucesso.\n";
					$state->{route} = $args->{npc};
					$state->{sellStart} = $state->{checkItem};
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $args->{getItemAmount};
					undef $state->{checkItem};
					undef $args->{retry};
					return;
				}
				elsif(defined($args->{getItemAmount})) {
					error "[merchBuyAuto] Ocorreu um erro ao tentar obter o item [".$state->{checkItem}."]\n";
					error "[merchBuyAuto] Iniciando uma nova tentativa...\n";
					$state->{getSent} = $state->{checkItem};
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{checkItem};
					return;
				}
				
				if((getItemAmount($state->{checkItem}) != $args->{sellItemAmount}) && defined($args->{sellItemAmount})){
					warning "[merchBuyAuto] O item [".$state->{checkItem}."] foi vendido com sucesso.\n";
					$state->{start} = 1;
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $args->{sellItemAmount};
					undef $state->{checkItem};
					undef $args->{retry};
					return;
				}
				elsif(defined($args->{sellItemAmount})){
					error "[merchBuyAuto] Ocorreu um erro ao tentar vender o item [".$state->{checkItem}."]\n";
					error "[merchBuyAuto] Iniciando uma nova tentativa...\n";
					$state->{sellStart} = $state->{checkItem};
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{checkItem};
					return;
				}
				
				if((getItemAmount($state->{checkItem}) == $args->{buyItemAmount}) && defined($args->{buyItemAmount})){
					warning "[merchBuyAuto] O item [".$state->{checkItem}."] foi comprado com sucesso.\n";
					$state->{route} = $args->{storage};
					$args->{addItemAmount} = $args->{buyItemAmount};
					$state->{addStart} = $state->{checkItem};
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $args->{buyItemAmount};
					undef $state->{checkItem};
					undef $args->{retry};
					return;
				}
				elsif(defined($args->{buyItemAmount})){
					error "[merchBuyAuto] Ocorreu um erro ao tentar comprar o item [".$state->{checkItem}."]\n";
					error "[merchBuyAuto] Iniciando uma nova tentativa...\n";
					$state->{buyStart} = $state->{checkItem};
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{checkItem};
					return;
				}
				
				
				if((getItemAmount($state->{checkItem}) != $args->{addItemAmount}) && defined($args->{addItemAmount})){
					
					$args->{maxAmount} = ($args->{maxAmount} - $args->{addItemAmount}); 
					
					if($args->{maxAmount} > 0){
						$state->{route} = $args->{npc};
						$state->{buyStart} = $state->{checkItem};
					}
					else {
						warning "[plugin:merchBuyAuto] A compra do item [".$state->{checkItem}."] foi finalizada.\n","success";
						$state->{start} = 1;
						undef $state->{checkItem};
						return;
					}
					warning "[merchBuyAuto] O item [".$state->{checkItem}."] foi armazenado com sucesso.\n";
					warning "[merchBuyAuto] Ainda preciso comprar mais: ".$args->{maxAmount}."\n";
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $args->{addItemAmount};
					undef $state->{checkItem};
					undef $args->{retry};
					return;
					
				}
				elsif(defined($args->{addItemAmount})){
					error "[merchBuyAuto] Ocorreu um erro ao tentar armazenar o item [".$state->{checkItem}."]\n";
					error "[merchBuyAuto] Iniciando uma nova tentativa...\n";
					$state->{addStart} = $state->{checkItem};
					$timeout{ai_merchBuyAuto}{time} = time;
					undef $state->{checkItem};
					undef $args->{addItemAmount};
					return;
				}
				
			}

		}
	}
}


sub fail {
	my (undef, $args) = @_;
	
	if ($args->{fail}) {
		$taskManager->add($charselect = Task::Timeout->new(
		name => 'charselect',
		inGame => 1,
		function => sub {
			warning "[merchBuyAuto] Tentando mudar de personagem...\n";
			Commands::run("charselect");
		},
		seconds => 5,
		stop => 1
	));	
	}
}


sub getItemInvSell {
	
	foreach my $itemInv (@{$char->inventory->getItems()}) {
		next if ($itemInv->{equipped});
		next if (!$itemInv->{sellable});
		
		if($_[0] eq $itemInv->{name}){
			return $itemInv->{index};
		}
	}

}

sub getItemInv {

	foreach my $itemInv (@{$char->inventory->getItems()}) {
		next if ($itemInv->{equipped});
		next if ($item->{broken} && $item->{type} == 7);
	
		if($_[0] eq $itemInv->{name}){
			return $itemInv->{index};
		}
		
	}
}

sub getItemId {
	foreach (keys %items_lut) {
		if (lc($items_lut{$_}) eq lc($_[0])) {
			return $_;
		}
	}
}

sub getStorageIndex {
	return findKeyString(\%storage, "name", $_[0]);
}


sub getInventoryIndex {
	my $item = $char->inventory->getByName($_[0]);
	return $item->{invIndex};
}

sub getItemAmount {
	return $char->inventory->sumByName($_[0]);
}

sub getSellItems {
	my %sellItemsList = split(/[:,]/, $config{"merchBuyAuto_$_[0]"."_sellItems"});
	my @sellItemsList;
	
	foreach my $name (keys %sellItemsList) {
		unshift @sellItemsList, {name => $name, weight => $sellItemsList{$name}};
	}
	return @sellItemsList;
}

;1
