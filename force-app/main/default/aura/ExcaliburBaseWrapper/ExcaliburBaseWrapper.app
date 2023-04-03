<!--
 - Created by Artsiom.Klimanski on 12/12/2019.
 -->

<aura:application description="ExcaliburBaseWrapper" access="GLOBAL" extends="ltng:outApp" implements="ltng:allowGuestAccess,forceCommunity:availableForAllPageTypes,force:appHostable,lightning:isUrlAddressable">
    <lightning:overlayLibrary aura:id="overlayLib" />
    <aura:dependency resource="c:excaliburBase" type="COMPONENT"/>
</aura:application>