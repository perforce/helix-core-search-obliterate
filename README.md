# Helix Core Search Obliterate

This project demonstrates how to keep the Helix Core Search service up-to-date with the latest submitted changes.  It uses an example Helix Core Lua Extension and is inteneded to be customised to suit a specific Helix installation.


## Overview

The Lua Extension will need to be installed on the Helix Core Server and is invoked by post-obliterate event.
This document describes the necessary steps to customize and install the extension to run on any Helix Core Server.


## Requirements

The extension requires a Helix Core Server version that supports extensions. This is 2019.1 or later for Linux systems.
You will also need the following correctly setup and working:

#### Helix Core Search service (p4search)
You'll need a 'p4search' service running and accessible from the Helix Core Server where this extension will be installed.

#### A Helix User for creating extension
Helix Server `super` access is required to create Server Side Extension.

#### Credentials to access p4search
You will need a valid `X-Auth-Token` defined in the 'p4search' configuration. 

## Deployment

(1) Ensure that the Helix Core Server has an extensions depot. If not, create one using

    p4 depot -t extension extensions
    
(2) Create a skeleton of a Helix Server Extension with name `helix-core-search-obliterate`. You need to be in the parent directory of `helix-core-search-obliterate`.

    git clone https://github.com/perforce/helix-core-search-obliterate.git
    
    p4 extension --package helix-core-search-obliterate
    
This will create an extension skeleton named `helix-core-search-obliterate.p4-extension`.
  
(3) Install the Helix Server Extension.

    p4 extension -y --install helix-core-search-obliterate.p4-extension
     	
(4) Configure the extension's global settings and specify the `X-Auth-Token` and `ExtP4USER` values.

    p4 extension --configure Perforce::helix-core-search-obliterate
    	
Add the `X-Auth-Token` and `P4Search obliterate url` in the `ExtConfig` at the end of `global-config.in` file (without altering spaces/tabs). 
    
        ExtConfig:
        	auth_token:	00000000-0000-0000-0000-000000000000
        	p4search_url: http://p4search.mydomain.com:4567/api/v1/obliterate

Change the `ExtP4USER` to your extension user.

(5) Configure the extension's instance settings.

    p4 extension --configure Perforce::helix-core-search-obliterate --name Perforce

(6) For more information on Helix Server Extensions, please refer to the [Helix Core Extensions Developer Guide](https://www.perforce.com/manuals/extensions/Content/Extensions/Home-extensions.html) 

## Useful commands

List the extensions on a Helix Core Server.

    p4 extension --list --type=extensions
        
List the extension's configurations.
    
    p4 extension --list --type=configs

Delete the extension's directory and extension from Helix Core Server.

    rm -f helix-core-search-obliterate.p4-extension    
    p4 extension -y --delete Perforce::helix-core-search-obliterate
