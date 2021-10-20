		.data

image: 		.asciiz "/home/emmanuel/Programmes/Terre.bmp"  	# Image en entrée
buffer: 	.space 1375000                                  	# Stockage du contenu de l'image
buffer2: 	.space 2750000		                       	 	# Stockage de la chaîne de caractères en caractères ascii
asciiArt: 	.asciiz "AsciiArt.txt"					# Fichier texte de sortie dans lequel sera créé l'ascii art

ascii: 		.asciiz "@W80&%6a#+*;,'. "				# Liste des caractères utilisés pour l'ascii art

retourLigne: 	.asciiz "\n"
espace: 	.asciiz " "						# Un espace entre les caractères permet avoir une "image texte" moins étroite et plus proche de l'image originale

ouvertureEchec:	.asciiz "L'ouverture du fichier est un échec. Vérifiez l'existence du fichier ou de son emplacement"
nonBMP:		.asciiz "Le fichier n'est pas un BMP"
tropVolumineux:	.asciiz "Le fichier a une taille supérieure à 1375000 octets"
BitsParPixel:	.asciiz "Le fichier doit comporter 8 bits par pixel"
Compression:	.asciiz "Les images compressées ne sont pas prises en charge"
		.align 2						# Pour éviter les problèmes d'alignement
arguments:	.space 12						# Utilisé pour respecter les conventions d'appel des fonctions
fin:		.asciiz "\nL'ascii art est aux emplacement et nom suivants (la racine du compte est le répertoire par défaut si le chemin n'est pas ou en partie indiqué): "

		.text

main:
  		li   $v0, 13						# Ouverture du fichier
  		la   $a0, image
  		li   $a1, 0
  		li   $a2, 0
  		syscall
  		move $s0, $v0         					# Sauvegarde du descripteur de fichier dans $s0

  		slti $t0, $s0, 0
  		bne  $t0, $0, erreurOuverture				# Arrêt du programme en cas d'échec d'ouverture du fichier

  		li   $v0, 14						# Lecture de l'image dans buffer
  		move $a0, $s0
  		la   $a1, buffer
  		li   $a2, 2000000					# Plus le nombre est grand, plus les images traitees peuvent contenir de pixels
  		syscall

		li   $v0, 16 						# Fermeture fichier: on n'en a plus besoin car son contenu est dans buffer
		add  $a0, $0, $s6					# Desciption du fichier à fermer
		syscall

		li   $t2, 256						# Multiplicateur utilisé pour la reconstruction du format, puis du volume

		lb   $a0, 0($a1)					# Les deux octets indiquant si le fichier est un bmp sont en 00 et 01 et valent respectivement 42 et 4D
		jal octetTest						# La valeur lue est parfois erronée, on effectue un test
		mult $v0, $t2
		mflo $t0
		lb   $t9, 1($a1)
		jal octetTest
		add  $t0, $t9, $t0
		bne  $t0, 16973, erreurFormat				# Si la valeur souhaitée n'est pas obtenue, le fichier n'est pas un bmp

		lb   $a0, 2($a1)					# La quatrième partie décrivant le nombre d'octets se trouve à l'octet 2 de buffer
		jal octetTest						# La valeur lue est parfois erronée, on effectue un test
		ori  $t9, $v0, 0
		lb   $a0, 3($a1)					# La seconde partie décrivant le nombre d'octets se trouve à l'octet 3 de buffer
		jal octetTest
		mult $v0, $t2
		mflo $t0
		add  $t9, $t9, $t0
		li   $t2, 65536						# Multiplicateur utilisé pour la reconstruction de la valeur du volume de l'image
		lb   $a0, 4($a1)					# La seconde partie décrivant le nombre d'octets se trouve à l'octet 4 de buffer
		jal octetTest
		mult $v0, $t2
		mflo $t0
		add  $t9, $t9, $t0
		li   $t2, 16777216					# Multiplicateur utilisé pour la reconstruction de la valeur du volume de l'image
		lb   $a0, 5($a1)					# La seconde partie décrivant le nombre d'octets se trouve à l'octet 5 de buffer
		jal octetTest
		mult $v0, $t2
		mflo $t0
		add  $t9, $t9, $t0					# Le nombre d'octets a été reconstitué
		bgt  $t9, 1375000, erreurVolume				# Volume maximum de l'image accepté de 1,375 Mo

		lb   $a0, 28($a1)					# L'octet 28 indique le nombre de bits par pixel.
		jal octetTest						# La valeur lue est parfois erronée, on effectue un test
		bne  $v0, 8, erreurBitsParPixel				# La valeur attendue est 8 bits par pixel (Les deux moitiés de l'octet sont identiques, il n'y a donc que 16 valeurs d'octets possibles: 0x00, 0x11,..., 0xFF)

		lb   $a0, 30($a1)					# L'octet 30 indique la compression. La valeur 0 indique qu'il n'y a pas de compression
		jal octetTest						# La valeur lue est parfois erronée, on effectue un test
		bne  $v0, 0, erreurCompression				# Les images compressées ne sont pas prises en charge.

		li   $t2, 256						# Multiplicateur utilisé pour la reconstruction des valeurs des dimensions de l'image. Une dimension est encodée sur 2 octets, dans l'ordre inverse. Par exemple une largeur de 1000 pixels (0x3E8) est encodée E8 03 et non 03 E8

		li   $t9, 0						# La largeur est stockée dans $t9
		lb   $a0, 18($a1)					# La seconde partie de la largeur se trouve à l'octet 18 de buffer
		jal octetTest						# La valeur lue est parfois erronée, on effectue un test
		add  $t9, $t9, $v0
		lb   $a0, 19($a1)					# La première partie de la largeur se trouve APRES la seconde, à l'octet 19 de buffer
		jal octetTest
		mult $v0, $t2
		mflo $t0
		add  $t9, $t9, $t0					# La valeur de la largeur est reconstruite

		li   $t8, 0						# La hauteur est stockée dans $t8
		lb   $a0, 22($a1)
		jal octetTest
		add  $t8, $t8, $v0
		lb   $a0, 23($a1)					# Octet suivant dans buffer
		jal octetTest
		mult $v0, $t2
		mflo $t0
		add  $t8, $t8, $t0					# La valeur de la hauteur est reconstruite

		mult $t8, $t9
		mflo $t3						# Le nombre de pixels est stocké dans $t3

		li   $t7, 0 						# Compteur pixel $t7
		li   $t6, 0						# Compteur largeur $t6
		addi $a1, $a1,1146 					# Placement aux premiers pixels (de la derniere ligne)

		addi $a0, $t9, 0					# Détermination du nombre d'octets à sauter à chaque fin de ligne: on calcule largeur mod(4)
modulo4:
		ble  $a0, 4, octets00FinLigne				# Branchement lorsque largeur mod(4) <= 4
		sub  $a0, $a0, 4
		j modulo4

octets00FinLigne:
		li   $t0, 4						# Sauter 4-(largeur mod(4)) octets dans buffer à chaque fin de ligne
		sub  $s7, $t0, $a0					# Nombre d'octets 00 à chaque fin de ligne dans $s7
		move $a2, $s7
		la   $a3, buffer2					# Pour les images bmp, les dernières lignes de l'image sont décrites avant les premières
		add  $t0, $t9, $t9					# On va donc se placer au bon endroit dans buffer2, pour y écrire la dernière ligne (celle du bas de l'image)
		subi $t1, $t8, 1
		mult $t0, $t1
		mflo $t0
		add  $a3, $a3, $t0					# On a obtenu l'adresse dans buffer2 où sera placé le début de la dernière ligne de "l'image texte"
		la   $t4, ascii						# Liste des caractères a imprimer dans le buffer2

#######################################################################

parcoursPixels:
		lb   $a0, 0($a1)					# $t0 contient la valeur de l'octet
		jal octetTest						# La valeur lue est parfois erronée (D'après de nombreux tests, cela concerne dans notre cas, les octets de valeur 0xXX, avec X allant de 8 à F, lus comme 0xFFFFFFXX). On effectue un test
		srl  $t2,$v0,4						# La valeur 0xXX est transformée en 0xX, avec X allant de 0 à F (16 valeurs différentes)
		add  $t1, $t4, $t2					# Calcul de l'adresse du caractère
		lb   $t1, 0($t1)					# Chargement du caractère souhaité
		sb   $t1, 0($a3)					# Le caractère est écrit dans buffer2
		addi $a3, $a3, 1					# Chaque caractère est suivi d'un espace pour un résultat plus proche de l'image d'origine
		la   $t1, espace
		lb   $t1, 0($t1)
		sb   $t1, 0($a3)

		addi $a3, $a3, 1					# Octet suivant dans buffer2
		addi $t7, $t7, 1					# On incrémente le nombre de pixels traités
		addi $t6, $t6, 1					# On incrémente le compteur largeur
		la   $a0, arguments					# Utilisé pour respecter les conventions d'appel des fonctions
		sw   $t3, 0($a0)					#
		sw   $t7, 4($a0)					#
		sw   $t9, 8($a0)					#
	 	beq  $t6, $t9, finLigne					# Lorsque tous les pixels d'une ligne ont été traités
	 	addi $a1, $a1, 1					# Octet suivant dans buffer
	 	j parcoursPixels

#######################################################################

dernierPixel:
		li   $v0, 4						# On affiche le contenu de buffer2
		la   $a0, buffer2
		syscall

		li   $v0, 13						# Ouverture du fichier texte de sortie
 	 	la   $a0, asciiArt
 		li   $a1, 1
  		li   $a2, 0
  		syscall

  		move $a0, $v0
  		li   $v0, 15						# Ecriture de buffer2 dans le fichier texte
  		la   $a1, buffer2
  		add  $a2, $t3, $t3					# Nombre de caracteres a écrire: pixels*2
  		syscall

  		li   $v0, 16						# Fermeture du fichier
  		syscall

  		la   $a0, fin						# Indication de la présence d'un fichier de sortie
		li   $v0, 4
		syscall

		la   $a0, asciiArt					# Indication de l'emplacement et du nom du fichier de sortie
		li   $v0, 4
		syscall

Sortie:
		li   $v0, 10						# Fin du programme
		syscall

#######################################################################

finLigne:
		lw   $t3, 0($a0)					# Valeur finalement écrasée par elle-même (pour le respect des conventions d'appel)
		lw   $t7, 4($a0)					# Valeur finalement écrasée par elle-même (pour le respect des conventions d'appel)
		lw   $t9, 8($a0)					# Valeur finalement écrasée par elle-même (pour le respect des conventions d'appel)
		subi $a3, $a3, 1
		la   $t6, retourLigne
		lb   $t6, 0($t6)
		sb   $t6, 0($a3)
		li   $t6, 0						# On réinitialise le compteur largeur
		beq  $t7, $t3, dernierPixel
		sub  $a3, $a3, $t9					# On calcule l'emplacement où stocker la ligne précédente dans buffer2
		sub  $a3, $a3, $t9					#
		sub  $a3, $a3, $t9					#
		sub  $a3, $a3, $t9					#
		addi $a3, $a3, 1					# On a obtenu l'emplacement de la ligne précédente dans buffer2
		add  $a1, $a1, $a2
		addi $a1, $a1, 1					# Première case de la ligne suivante dans buffer
		j parcoursPixels

octetTest:	move $v0, $a0						# Certains octets pour les dimensions sont lus avec une valeur inférieure de 256 à celle réelle
		bltz $v0, problemeOctet					# Si les octets sont négatifs, on les transforme en octets positifs en ajoutant 256
		jr   $ra

problemeOctet:								# On transforme la valeur en valeur positive. L'origine de ce problème est indéterminée
		addi $v0, $a0, 256
		jr   $ra

erreurFormat:
		la   $a0, nonBMP
		li   $v0, 4
		syscall
		j Sortie

erreurVolume:
		la   $a0, tropVolumineux
		li   $v0, 4
		syscall
		j Sortie

erreurBitsParPixel:
		la   $a0, BitsParPixel
		li   $v0, 4
		syscall
		j Sortie

erreurCompression:
		la   $a0, Compression
		li   $v0, 4
		syscall
		j Sortie

erreurOuverture:
		la   $a0, ouvertureEchec
		li   $v0, 4
		syscall
		j Sortie
