--
-- processeur.vhd
--
-- processeur à usage général
--
-- Pierre Langlois
-- v. 1.9 2008/11/01 pour labo 5, INF3500 automne 2008
-- version donnée aux étudiants
--
-- Par rapport aux notes de cours (v. 1.53), cette version comporte les changements suivants:
-- 1. inclut le chargement d'une valeur immédiate de 16 bits.
-- 		OP code: 1010 | registre-destination | - | -
-- 2. reset asynchrone au lieu de synchrone
-- 3. sortie externe gardée dans un registre
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity processeurv19 is
	generic (
		Nreg : integer := 16; 	-- nombre de registres
		Wd : integer := 16; 	-- largeur du chemin des données en bits
		Wi : integer := 16; 	-- largeur des instructions en bits						
		Mi : integer := 8; 		-- nombre de bits d'adresse de la mémoire d'instructions
		Md : integer := 8; 		-- nombre de bits d'adresse de la mémoire des données
		resetvalue : std_logic := '1'
	);
	port(						
		CLK : in std_logic;		
		reset : in std_logic;  		  
		entreeExterne : in signed(Wd - 1 downto 0);																	   
		fifoInNotReady : in std_logic;				 -- Indique si une requête du processeur de lecture est impossible
		fifoOutNotReady  : in std_logic;			 -- Indique si une requête du processeur d'écriture est impossible 
		sortieExterne : out signed(Wd - 1 downto 0); 				  
		entreeExterneALire  : out std_logic;		 -- Envoie une requête de lecture
		sortieExterneValide : out std_logic										   
	);
end processeurv19;

architecture arch of processeurv19 is
-- signaux de la mémoire des instructions
type memoireInstructions_type is array (0 to 2 ** Mi - 1) of std_logic_vector(Wi - 1 downto 0);
--signal memoireInstructions : memoireInstructions_type := (others => (others => '1'));
constant memoireInstructions : memoireInstructions_type :=
--	(x"0752", x"190b", x"7840", x"8cf0", x"9a1c", x"c102", others => (others => '1')); 				-- exemple des notes
--	(x"8000", x"8101", x"1C01", x"C406", x"8704", x"1C7C", x"9C03", others => (others => '1')); 	-- différence absolue M[3] = |M[0] - M[1]| 
--	(x"A700", x"0005", x"AC00", x"0003", x"137C", others => (others => '1')); 						-- chargement valeur immédiate 16 bits  																						 
--	(x"A100", x"0002", x"A200", x"0004", x"9202", x"E510", others => (others => '1')); 				-- test d'une lecture de la memoire adresser par le contenue de R[1] dans R[5]
--	(x"A100", x"0000", x"A200", x"0004", x"E012", others => (others => '1')); 						-- test d'une écriture dans la mémoire de donnée de R[2] adressé par R[1]
--	(x"B100", x"B200", x"B300", x"B400", x"B500", x"B600", others => (others => '1')); 				-- test d'une lecture externe
--	(x"B100", x"B200", x"B300", x"D300", x"D200", x"D100", others => (others => '1')); 				-- test d'une ecriture externe
(
-- *Conventions*
-- false = 0
-- true = 1
-- R[0] = usage général (opUAL, swap, variables temporaires)
-- R[1] = usage général (opUAL, swap, variables temporaires)
-- R[2] = usage général (opUAL, swap, variables temporaires)
-- R[3] = caractère entrant
-- R[4] = compteur
-- R[5] = adresse de début du tampon := 9
-- R[6] = 0x30 = borne inférieur pour un caractère valide
-- R[7] = 0x39 = borne supérieur pour un caractère valide
-- R[8] = adresse de début du tampon = 9 (scope d'un for)
-- R[9] = libre
-- R[10] = libre
-- R[11] = libre
-- R[12] = libre
-- R[13] = libre
-- R[14] = libre
-- R[15] = libre

-- Constantes:
-- N = 40 = 0x28 (x"9000")
-- BACKSPACE (x"9001") = 0x7
-- ENTER(x"9002") = 0xD
x"A000",x"0028", x"9000", -- N = 40 = 0x28 	(0)
x"A000",x"007F", x"9001", -- BACKSPACE 		(3)
x"A000",x"000D", x"9002", -- ENTER 			(6)

-- Initialisation variables:
-- compteur(x"9003")  = 0 
-- status_cls(x"9004") = false
-- caractere_invalid(x"9005") = false
-- cls[0] (x"9006"), cls[1] (x"9007"), cls[2] (x"9008") 
-- tampon[0] (x"9009")...tampon[39] (x"9048")
x"A000",x"0000",x"9003", x"9004", x"9005", x"9006", x"9007", x"9008", -- (9)

-- Envoie du prompt (>> ): 
x"A000", x"003E", x"A100", x"0020", -- (17)
x"D000", x"D000", x"D100", 			-- (21)

-- Constantes pour tests logiques:
x"8403",			-- R[4] = compteur 	(24)
x"A500", x"0009",	-- R[5] = i = 9,	(25)

-- Réception des données:
x"B300",			-- R[3] = temp 		(27)

-- if (compteur == 0 && temp == BACKSPACE)
-- Ignorer tout nouveau caractère d'effacement seulement si le tampon est vide
x"A000", x"0000",	-- R[0] = 0,						(28)
x"1004", x"C224", 	-- compteur == 0 (jnz else if) 		(30)
x"8001",			-- R[0] = BACKSPACE 				(32)
x"1003", x"C11B", 	-- temp == BACKSPACE (jz Réception) (33)
x"C038",			-- jump à ENTER						(35)

-- else if (compteur == N && temp == BACKSPACE)	
-- Après 40 caractères, votre console doit ignorer les nouvelles entrées sauf le caractère d'effacement (0x7F)
x"8000",			-- R[0] = N 						(36)
x"1004", x"C22B", 	-- compteur == N (jnz else) 		(37)
x"8001",			-- R[0] = BACKSPACE 				(39)
x"1003", x"C12E", 	-- temp == BACKSPACE (jz Effacer)	(40)
x"C038",			-- jump à ENTER						(42)

-- else:
	-- if temp == BACKSPACE
	x"8001",			-- R[0] = BACKSPACE 				(43)
	x"1003", x"C238", 	-- temp == BACKSPACE (jnz else if) 	(44)
	-- Effacer:
	x"D300", 			-- echo								(46)
	x"A000", x"0001",	-- R[0] = 1							(47)
	x"1440", 			-- compteur -= 1 					(49)
	x"1550", 			-- i -= 1;							(50)
	x"9403", 			-- memoiresDeDonnes(3) = compteur	(51)
	x"C01B", 			-- (jmp Réception des données)		(52)
	
	-- else if (compteur < N)
	x"8000",			-- R[0] = N 						(53)
	x"1004", x"C31B", 	-- compteur < N (jpos Réception) 	(54)
		
		-- if (temp == ENTER) 
		x"8002",			-- R[0] = ENTER 					(56)
		x"1003", x"C2AD", 	-- temp == ENTER (jnz Emmagasine) 	(57)
		x"C040",			-- (jmp check_valid) 				(59)
		
			-- set_caractere_invalid
			x"A000", x"0001",	-- R[0] = 1							(60)
			x"9005", 			-- memoiresDeDonnes(5) = R[0]		(62)
			x"C057", 			-- (jmp status_cls) 				(63)
		
			-- check_valid:
			-- Boucle for pour verifier si les caracteres entre sont valide
			x"A600", x"0030", 	-- R[6] = 0x30 = borne inférieur			(64)
			x"A700", x"003A", 	-- R[7] = 0x3A = borne supérieur			(66)
			x"A800", x"0009", 	-- R[8] = k = 9	 							(68)
			x"E180", 			-- R[1] = tampon(R[8])   					(70)
			-- if (tampon[i] < (0+48))
				x"1016", x"C33C", 	-- jump a set_caractere_invalid			(71)
			-- if (tampon[i] > (9+48))
				x"1017", x"C43C", 	-- jump a set_caractere_invalid 		(73)
			x"A000", x"0001",	-- incrément								(75)
			x"0808",			-- ++k										(76)
			x"A100", x"0009",	-- R[1] = 9									(78)
			x"1181",			-- R[1] = R[8] - 9							(80)
			x"8003",			-- R[0] = memoiresDeDonnes(3) = compteur	(81)
			x"1010", x"C346", 	-- k - 9 < compteur (jneg à x"E810")		(82)
			-- Dans le cas où il n'y a pas de caractères invalides
			x"A000", x"0000", 	-- R[3] = caractere_invalid = 0 			(84)
			x"9005", 			-- memoiresDeDonnes(5) = caractere_invalid	(86)
			
			-- if (status_cls && compteur < 3)
			-- status_cls
				x"8004",			-- R[0] = status_cls 					(87)
				x"A100", x"0001", 	-- R[1] = 1								(88)
				x"1101", x"C264", 	-- jnz Écriture MSG: 					(90)
				x"A100", x"0003",	-- R[1] = 3								(92)
				x"1141", x"C264", 	-- if (compteur == 3) jnz Écriture MSG: (94)
			
				-- Envoie cls
				x"A000", x"000C",  x"D000", -- \f			(96)
				x"C000", -- boucle infini					(99)
			
			-- Écriture MSG: 
			-- if (compteur == 0) ne pas afficher OK
				x"8003",			-- R[3] = compteur 							(100)
				x"A100", x"0000", 	-- R[1] = 0 								(101)
				x"1101", x"C276", 	-- jnz Envoie else if(caractere_invalide)	(103)
				x"A000", x"000D",  x"D000", -- \r 	(105)
				x"A000", x"000A",  x"D000", -- \n  	(109)
				x"A000", x"000D",  x"D000", -- \r 	(111)
				x"A000", x"000A",  x"D000", -- \n  	(114)
				x"C000", -- boucle infini			(117)
			
			-- else if(caractere_invalide)
				x"8005",			-- R[0] = caractere_invalid 	(118)
				x"A100", x"0001", 	-- R[1] =  1					(119)
				x"1101", x"C29A", 	-- jnz Envoie OK 				(121)
			
				-- Envoie ERREUR
				x"A000", x"000D",  x"D000", -- \r 	(123)
				x"A000", x"000A",  x"D000", -- \n  	(126)
				x"A000", x"0045",  x"D000", -- E  	(129)
				x"A000", x"0052",  x"D000", -- R  	(132)
				x"A000", x"0052",  x"D000", -- R  	(135)
				x"A000", x"0045",  x"D000", -- E   	(139)
				x"A000", x"0055",  x"D000", -- U  	(142)
				x"A000", x"0052",  x"D000", -- R   	(144)
				x"A000", x"000D",  x"D000", -- \r  	(147)
				x"A000", x"000A",  x"D000", -- \n  	(150)
				x"C000", -- boucle infini			(153)
			
			-- else
				-- Envoie OK
				x"A000", x"000D",  x"D000", -- \r  	(154)
				x"A000", x"000A",  x"D000", -- \n  	(157)
				x"A000", x"004F",  x"D000", -- O   	(160)
				x"A000", x"004B",  x"D000", -- K   	(163)
				x"A000", x"000D",  x"D000", -- \r  	(165)
				x"A000", x"000A",  x"D000", -- \n  	(169)
				x"C000", -- boucle infini	 		(172)
			
		-- else
			-- Emmagasine:
			-- Emmagasiner le nouveau caractère et faire l'echo
			-- else if (compteur < N)
			x"8000",			-- R[0] = N 						(173)
			x"1004", x"C11B", 	-- compteur == N (jpos Réception) 	(174)
			
			x"D300", -- echo	 			(176)
			x"E053", -- tampon(R[5]) = R[3] (177)
			
			-- test_cls:
			x"A100", x"0003",	-- R[1] = 3								(178)
			x"1141", x"C4BA", 	-- if (compteur < 3) jpos Incrémenter 	(180)
			x"A100", x"0006",	-- R[1] = 6	adresse de début de cls		(182)
			x"0114",			-- Adresse dans cls						(184)	
			x"E013", 			-- cls(R[1]) = temp;  					(185)
			
			-- Incrémenter:
			x"A000", x"0001",	-- R[0] = incrément						(186)
			x"0505", 			-- i += 1;								(188)
			x"0404", 			-- compteur += 1;						(189)
			x"9403", 			-- memoiresDeDonnes(3) = compteur;		(190)
			
			-- cls[0] == 'c' 						
			x"A000", x"0063", 	-- R[0] = 'c'					(191)
			x"8106",			-- R[1] = cls[0]				(193)
			x"1001",			-- cls[0] == 'c'				(194)
			x"C2D2", 			-- jump set_status_cls_false	(195)
			
			--  cls[1] == 'l'
			x"A000", x"006C", 	-- R[14] = 'l'					(196)
			x"8107",			-- R[15] = cls[0]				(198)
			x"1001",			-- cls[1] == 'l'				(199)
			x"C2D2", 			-- jump set_status_cls_false	(200)
			
			-- cls[2] == 's'
			x"A000", x"0073", 	-- R[14] = 's'					(201)
			x"8108",			-- R[15] = cls[0]				(203)
			x"1001",			-- cls[2] == 's'				(204)
			x"C2D2", 			-- jump set_status_cls_false	(205)
		
		-- set_status_cls_true
		x"A000", x"0001", 	-- R[0] = 1								(206)
		x"9004",			-- memoiredeDonnes = R[3]				(208)
		x"C01B",			-- jmp Réception nouveaux caractères	(209)
		
		-- set_status_cls_false
		x"A000", x"0000", 	-- R[0] = 0								(210)
		x"9004",			-- memoiredeDonnes = R[3] 				(212)
		x"C01B",			-- jmp Réception nouveaux caractères	(213)
		
others => (others => '1') -- (214)
);

-- signaux de la mémoire des données
type memoireDonnees_type is array(0 to 2 ** Md - 1) of signed(Wd - 1 downto 0);
signal memoireDonnees : memoireDonnees_type;
signal sortieMemoireDonnees : signed(Wd - 1 downto 0);
signal adresseMemoireDonnees : integer range 0 to 2 ** Md - 1;
signal lectureEcritureN : std_logic;
signal lectureAdresseR, ecrireAdresseR : std_logic;

-- signaux du bloc des registres
type lesRegistres_type is array(0 to Nreg - 1) of signed(Wd - 1 downto 0);
signal lesRegistres : lesRegistres_type;
signal A : signed(Wd - 1 downto 0);
signal choixA : integer range 0 to Nreg - 1;
signal B : signed(Wd - 1 downto 0);
signal choixB : integer range 0 to Nreg - 1;
signal donnee : signed(Wd - 1 downto 0);
signal choixCharge : integer range 0 to Nreg - 1;		  	   
signal charge : std_logic;							 					
signal entreeExterneValide : std_logic := '0';

-- Nouveaux signaux
signal lireExterneReady : std_logic := '0';
signal no_reg : integer range 0 to Nreg - 1;

-- signaux du multiplexeur contrôlant la source du bloc des registres
signal constante : signed(Wd - 1 downto 0);
signal choixSource : integer range 0 to 3;

-- signaux de l'UAL
signal F : signed(Wd - 1 downto 0);
signal Z : std_logic;
signal N : std_logic;
signal op : integer range 0 to 7;

-- signaux de l'unité de contrôle
type type_etat is
	(depart, querir, decoder, stop, ecrireMemoire, lireMemoire, opUAL, jump, chargeimm16, lireExterne, ecrireExterne, lireEcrireMemoire);
signal etat : type_etat;
signal PC : integer range 0 to (2 ** Mi - 1); -- compteur de programme
signal IR : std_logic_vector(Wi - 1 downto 0); -- registre d'instruction   

begin
	-- =========================== PROCESSEUR ===========================
	-- multiplexeur pour choisir la source du bloc des registres
	process (F, constante, entreeExterne, sortieMemoireDonnees, choixSource)
	begin
		case choixSource is 
			when 0 => donnee <= F; 
			when 1 => donnee <= constante;
			when 2 => donnee <= entreeExterne;
			when 3 => donnee <= sortieMemoireDonnees;
			when others => donnee <= F;
		end case;
	end process;
	constante <= signed(memoireInstructions(PC)); -- chargement de valeur immédiate, 16 bits
	
	-- bloc des registres				
	process (CLK, reset)
	begin
		if reset = resetvalue then
			lesRegistres <= (others => (others => '0'));
		elsif rising_edge(CLK) then
			if charge = '1' then
				lesRegistres(choixCharge) <= donnee;	 
			elsif lectureAdresseR = '1' then
				lesRegistres(choixCharge) <= memoireDonnees(adresseMemoireDonnees);	   
			elsif lireExterneReady = '1' then  
				lesRegistres(no_reg) <= entreeExterne;
			end if;
		end if;
	end process;
	
	-- signaux de sortie du bloc des registres
	A <= lesRegistres(choixA);
	B <= lesRegistres(choixB);
	
	-- Signal de sortie pour l'ecriture externe
	sortieExterne <= lesRegistres(choixCharge);
	
	-- unité de contrôle
	process (CLK, reset)
	begin
		if reset = resetvalue then
			etat <= depart;
		elsif rising_edge(CLK) then
			case etat is
				when depart =>
					PC <= 0;
					etat <= querir;
				when querir =>
					sortieExterneValide <= '0';		  -- tombe à 0 après un cycle d'horloge dans ecrireExterne 
					entreeExterneALire <= '0';		  -- tombe à 0 après un cycle d'horloge dans lireExterne  
					entreeExterneValide <= '0';
					IR <= memoireInstructions(PC);
					PC <= PC + 1;
					etat <= decoder;
				when decoder =>
					if (IR(15) = '0') then
						etat <= opUAL;
					else
						case IR(14 downto 12) is							
							when "000" => etat <= lireMemoire;
							when "001" => etat <= ecrireMemoire;
							when "010" => etat <= chargeImm16; 
							when "011" => etat <= lireExterne;
							when "100" => etat <= jump;		  
							when "101" => etat <= ecrireExterne;
							when "110" => etat <= lireEcrireMemoire; 
							when "111" => etat <= stop;
							when others => etat <= stop;
						end case;
					end if;
				when opUAL | lireMemoire | ecrireMemoire =>
					etat <= querir;
				when jump =>
					if 	(IR(11 downto 8) = "0000") or -- branchement sans condition
						(IR(11 downto 8) = "0001" and Z = '1') or -- si = 0
						(IR(11 downto 8) = "0010" and Z = '0') or -- si /= 0
						(IR(11 downto 8) = "0011" and N = '1') or -- si < 0
						(IR(11 downto 8) = "0100" and N = '0') -- si >= 0
					then
						PC <= to_integer(unsigned(IR(7 downto 0)));
					end if;
					etat <= querir;
				when chargeImm16 =>
					etat <= querir;
					PC <= PC + 1;	   
				when stop =>
					etat <= stop;
				when lireExterne =>
					if fifoInNotReady = '0' then
						entreeExterneALire <= '1'; 
						entreeExterneValide <= '1';
						etat <= querir;
					end if;								
				when ecrireExterne => 
					if fifoOutNotReady = '0' then
						sortieExterneValide <= '1';
						etat <= querir;
					end if;
				when lireEcrireMemoire =>
					 etat <= querir;
				when others =>
					etat <= depart;
			end case;
		end if;
	end process;
	
	process(clk)
	begin
		if (rising_edge(clk)) then	  
			if entreeExterneValide = '1' then 
				lireExterneReady <= '1';
				no_reg <= choixCharge;
			else
				lireExterneReady <= '0';
			end if;			   
		end if;
	end process;
	
	-- signaux de sortie de l'unité de contrôle
	adresseMemoireDonnees <= to_integer(A) when etat = lireEcrireMemoire else to_integer(unsigned(IR(7 downto 0)));
	lectureEcritureN <= '0' when etat = ecrireMemoire else '1';
	lectureAdresseR <= '1' when (choixB = 0 and choixCharge /= 0) and etat = lireEcrireMemoire else '0';
	ecrireAdresseR <= '1' when etat = lireEcrireMemoire and choixCharge = 0 else '0';
	
	with etat select
		choixSource <=
			0 when opUAL,
			1 when chargeImm16,
			2 when lireExterne,
			3 when others;
	choixCharge <= to_integer(unsigned(IR(11 downto 8)));
	choixA <= to_integer(unsigned(IR(7 downto 4)));
	choixB <= to_integer(unsigned(IR(11 downto 8))) when etat = ecrireMemoire else
		to_integer(unsigned(IR(3 downto 0)));
	with etat select
		charge <=
		'1' when opUAL | lireMemoire | chargeImm16,
		'0' when others;		
	op <= to_integer(unsigned(IR(14 downto 12)));
	
	-- UAL
	process(A, B, op)
	begin
		case op is	
			when 0 => F <= A + B;
			when 1 => F <= A - B;
			when 2 => F <= shift_right(A, 1);
			when 3 => F <= shift_left(A, 1);
			when 4 => F <= not(A);
			when 5 => F <= A and B;
			when 6 => F <= A or B;
			when 7 => F <= A;
			when others => F <= (others => 'X');
		end case;
	end process;
	
	-- registre d'état de l'UAL
	process(clk, reset)
	begin
		if reset = resetvalue then
			Z <= '0';
			N <= '0';
		elsif rising_edge(clk) then
			if (etat = opUAL) then
				if F = 0 then Z <= '1'; else Z <= '0'; end if;
				N <= F(F'left);
			end if;
		end if;
	end process;
	
	-- mémoire des données
	process (CLK)
	begin
		if rising_edge(CLK) then
			if lectureEcritureN = '0' then
				memoireDonnees(adresseMemoireDonnees) <= B;
			elsif ecrireAdresseR = '1' then
				if adresseMemoireDonnees <= 255 then
					memoireDonnees(adresseMemoireDonnees) <= B;
				end if;
			end if;
		end if;
	end process;
	sortieMemoireDonnees <= memoireDonnees(adresseMemoireDonnees);
			
	-- signaux de sortie pour déboguage
--	PCout <= std_logic_vector(to_unsigned(PC, PCout'length));
--	Fout <= std_logic_vector(F(Fout'length - 1 downto 0));
--	etatout <= std_logic_vector(to_unsigned(type_etat'pos(etat), etatout'length));
--	Zout <= Z;
--	Nout <= N;
	
end arch;

