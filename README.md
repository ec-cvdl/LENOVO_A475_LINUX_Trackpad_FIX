# LENOVO_A475_LINUX_Trackpad_FIX
Un script permettant de corriger le fonctionnement du Trackpad sous Linux Mint du Lenovo A475

## Problème identifié
Le Lenovo A475 est un modèle qui ne dispose pas de tous les pré-requis afin de passer sous Windows 11 : pas de pilote d'affichage (dû au processeur AMD), et le passage sous Linux ne permet pas de l'utiliser correctement : le Trackpad (ou la souris) se désactive si la batterie tombe à plat ou est retirée de son emplacement.

Il s'agit en réalité du pilote qui ne se charge pas au lancement de l'ordinateur.

## La solution simple et manuelle
Pour corriger ce problème de manière simple, il suffit simplement de mettre l'ordinateur en veille (soit en passant par le système, soit en fermer le capot de l'ordiateur). Ainsi, la sortie de veille va relancer le pilote manquant et faire fonctionner de nouveau le Trackpad.

## La solution automatisée
Rendre cela automatique au sein d'un script est le meilleur moyen d'éviter tout futur problème avec ce modèle spécifique. Le script va installer du code permettant de s'activer à chaque démarrage/redémarrage de l'ordinateur, et ainsi éviter les problèmes lorsque la batterie est, soit retirée, soit vidée.

Pour exécuter le script sur un Lenovo A475 :
1- Téléchargez le script [https://raw.githubusercontent.com/ec-cvdl/LENOVO_A475_LINUX_Trackpad_FIX/refs/heads/main/fix-touchpad.sh](ici)
2- Ouvrez un Terminal à l'endroit où le script a été téléchargé
3- Tapez la commande suivante :
  ```bash
chmod +x fix-touchpad.sh
```
4- Exécutez le script avec la commande suivante :
  ```bash
sudo bash fix-touchpad.sh
```
