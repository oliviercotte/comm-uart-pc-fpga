/****************************************************************************
 * Fichier: main.cpp
 * Auteur: Olivier Cotte
 * Date: ao�t 2012
 * Description: Sp�cification fonctionnelle de l'algorithme du processeur en vue de sa r�alisation.
 ****************************************************************************/

#include <iostream>
#include <conio.h>

#define N 40
#define BACKSPACE 8 // d�pendant de la machine (je ne connais pas le caract�re)
#define ENTER '\r' // 13

int main() {
	char cls[3];
	char fifo[N-1];
	char temp = 0;
	int compteur = 0;
	bool caractere_invalide = false, status_cls = false;
	
	while(1) {
		caractere_invalide = false;
		status_cls= false;
		compteur = 0;
		temp = 0;
		cls[0] = 0;
		cls[1] = 0;
		cls[2] = 0;

		printf(">> ");

		while (temp != ENTER) {
			temp = getch();
			if (compteur == 0 && temp == BACKSPACE) { // ignorer tout nouveau caract�re d'effacement seulement si le tampon est vide
			}
			else if (compteur == N && temp == BACKSPACE) { // Apr�s 40 caract�res, votre console doit ignorer les nouvelles entr�es sauf le caract�re d'effacement (0x7F)
				printf("%c", temp); // pour l'echo
				compteur -= 1;
			}
			else {
				if (temp == BACKSPACE) { // caract�re d'effacement
					compteur -= 1;
					printf("%c", temp);
				}
				else if (compteur < N) { 
					if (temp == ENTER) { // L'utilisateur � pes� ENTER
						for (int i = 0; i < compteur; ++i) { // V�rifier si les caract�res dans le tampon sont valide
							if (fifo[i] == ENTER)
								break;
							if (fifo[i] < '0' || fifo[i] > '9') {
								caractere_invalide = true;
								break;
							}
						}
						if (status_cls && compteur == 2) { // L'utilisateur � la possibilit� d'entrer "<< cls" pour clear-screen
							system("cls");
						}
						else if(caractere_invalide) {
							printf("\nErreur\n");
						}
						else {
							printf("\nOK\n");
						}
					}
					else { // Emmagasiner le nouveau caract�re et faier l'echo
					fifo[compteur] = temp;
					printf("%c", fifo[compteur]);
					if (compteur < 3) { // V�rifie pour le cls
						cls[compteur] = temp;
					}
					status_cls = cls[0] == 'c' && cls[1] == 'l' && cls[2] == 's';
					compteur += 1;
					}
				}
			}
		}
	}
	return 0;
}
