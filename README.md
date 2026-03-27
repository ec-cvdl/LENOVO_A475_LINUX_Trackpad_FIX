# LENOVO_A475_LINUX_Trackpad_FIX
Un script permettant de corriger le fonctionnement du Trackpad sous Linux Mint du Lenovo A475

## Problème identifié
Le Lenovo A475 est un modèle qui ne dispose pas de tous les pré-requis afin de passer sous Windows 11 : pas de pilote d'affichage (dû au processeur AMD), et le passage sous Linux ne permet pas de l'utiliser correctement : le Trackpad (ou la souris) se désactive si la batterie tombe à plat ou est retirée de son emplacement.

Il s'agit en réalité du pilote qui ne se charge pas au lancement de l'ordinateur.

## La solution simple et manuelle
Pour corriger ce problème de manière simple, il suffit simplement de mettre l'ordinateur en veille (soit en passant par le système, soit en fermer le capot de l'ordiateur). Ainsi, la sortie de veille va relancer le pilote manquant et faire fonctionner de nouveau le Trackpad.

## La solution automatisée
Rendre cela automatique au sein d'un script est le meilleur moyen d'éviter tout futur problème avec ce modèle spécifique. Le script va donc s'exécuter à chaque redémarrage de l'ordinateur, afin d'éviter le problème à l'avenir.