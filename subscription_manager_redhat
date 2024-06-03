#!/bin/bash

# Enregistrement dans RedHat (mmobioh ; Sorbonne@2023)
echo "Enregistrement dans RedHat :"
echo "Nettoyage des informations d'inscription précédentes"
subscription-manager clean
echo "Enregistrement de l'utilisateur [mmobioh]"
subscription-manager register --username=mmobioh --password=Sorbonne@2023
echo "Affichage de la liste des abonnements disponibles"
subscription-manager list --available
echo "Attachement de l'abonnement spécifique identifié par le code de pool 8a85f99977b0c0420177f2a086211111s"
subscription-manager attach --pool=8a85f99977b0c0420177f2a086211111
echo "*** Abonnement Redhat 8a85f99977b0c0420177f2a086211111 attaché ***"
sleep 3
