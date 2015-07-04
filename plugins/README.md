# merchBuyAuto

por **Paranoid**

### Descrição

Ao iniciar o processo do **getAuto**, o plugin verifica se o item requerido existe no inventário e no armazém em uma quantidade inferior a definida no campo **minAmount**.  
Caso não exista, ele irá logar em outro personagem pré-definido e irá verificar se a quantidade de zenys é maior que a definida no campo **zeny**, caso seja, ele irá iniciar a compra do item requerido até o limite definido no campo **maxAmount**. Se for menor, ele irá vender os itens definidos no campo **sellItems** até alcançar uma quantidade superior a quantidade definida no campo **zeny**. Após efetuar as vendas, ele irá iniciar a compra do item.  



### Sintaxe
```
merchBuyAuto <nome do item> {
	weight <peso do item>
	char <id do personagem para compras>
	npc <nome do mapa <x> <y>>
	distance <distância do NPC em números>
	storage <nome do mapa <x> <y>
	storageSteps <sequência de conversa com a Kafra>
	minAmount <quantidade mínima do item>
	maxAmount <quantidade máxima do item>
	sellItems <item:peso,item:peso>
	zeny <quantidade mínima de zenys>
	disabled <desabilita o bloco de configuração>
}
```

### Definição das condições

**weight** - Peso do item requerido.  
**char** - Número do slot do personagem que irá vender/comprar itens. Em caso de dúvida, inicie o openkore com o campo char desabilitado e verifique os números dos slots dos seus personagens.
**npc** - Localização do NPC onde os itens serão vendidos/comprados.  
**storage** - Localização da kafra onde os itens serão obtidos/armazenados.  
**storageSteps** - Sequência de conversa com a kafra.  
**distance** - Especifica a qual distância o personagem deverá permenecer dos NPCs.  
**minAmount** - Quantidade mínima do item requerido no inventário/armazém. Especifique essa opção com o mesmo valor definido no campo maxAmount do **getAuto**.  
**maxAmount** - Quantidade máxima a ser comprada do item requerido.  
**sellItems** - Itens que poderão ser vendidos para obter zenys suficientes para a compra do item requerido.  
**zeny** - Especifica a quantidade mínima de zenys para compra do item requerido.  
**disabled** - Caso esta opção seja especificada como 1, o bloco de configuração será desabilitado.  


### Exemplo de uso

Observe que o campo minAmount está com o mesmo valor do campo maxAmount do bloco getAuto.  

```
merchBuyAuto Poção Laranja {
	weight 10
	char 1
	npc payon_in01 5 49
	storage payon 181 104
	storageSteps c r1 c
	distance 5
	minAmount 150
	maxAmount 1000
	sellItems Pele de Lontra:1,Safira:10,Cyfar:1
	zeny 250000
}
```
```
getAuto Poção Laranja {
	minAmount 0
	maxAmount 150
	passive
}
```
