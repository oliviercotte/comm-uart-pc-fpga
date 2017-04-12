/****************************************************************************
 * Fichier: main.cpp
 * Auteur: Olivier Cotte
 * Date: août 2012
 * Description: Spécification fonctionnelle de l'algorithme du processeur en vue de sa réalisation.
 ****************************************************************************/

#include <iostream>
#include <conio.h>

#define N 40
#define BACKSPACE 8 // dépendant de la machine (je ne connais pas le caractère)
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
			if (compteur == 0 && temp == BACKSPACE) { // ignorer tout nouveau caractère d'effacement seulement si le tampon est vide
			}
			else if (compteur == N && temp == BACKSPACE) { // Après 40 caractères, votre console doit ignorer les nouvelles entrées sauf le caractère d'effacement (0x7F)
				printf("%c", temp); // pour l'echo
				compteur -= 1;
			}
			else {
				if (temp == BACKSPACE) { // caractère d'effacement
					compteur -= 1;
					printf("%c", temp);
				}
				else if (compteur < N) { 
					if (temp == ENTER) { // L'utilisateur à pesé ENTER
						for (int i = 0; i < compteur; ++i) { // Vérifier si les caractères dans le tampon sont valide
							if (fifo[i] == ENTER)
								break;
							if (fifo[i] < '0' || fifo[i] > '9') {
								caractere_invalide = true;
								break;
							}
						}
						if (status_cls && compteur == 2) { // L'utilisateur à la possibilité d'entrer "<< cls" pour clear-screen
							system("cls");
						}
						else if(caractere_invalide) {
							printf("\nErreur\n");
						}
						else {
							printf("\nOK\n");
						}
					}
					else { // Emmagasiner le nouveau caractère et faier l'echo
					fifo[compteur] = temp;
					printf("%c", fifo[compteur]);
					if (compteur < 3) { // Vérifie pour le cls
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
