<img src="http://i.imgur.com/DtAkHI6.png"  />

-----------

## Introduction  
`Moniteur` is an automated monitoring tool for [Tableau Server](http://www.tableau.com/products/server). It keeps watch on the performance of published workbooks and data connections (via the Tableau backend Postgres database) and emails publishers about issues. 
 
#### Summary  
[Tableau](http://www.tableau.com/) enables a distributed group of developers to create and share visualizations through Tableaau Server - `moniteur` is meant to keep those developers (and the server admins) *informed* across their growing collection of workbooks and connections with the goal of keeping the Tableau Server running smoothly.

More specifically, `moniteur` includes a **backend** (scripts and a database) that is meant to run daily and check for Tableau Server "infractions" in order to send alert emails to owners and (optionally) to archive server objects (workbooks or connections). Server infractions are found by querying the backend Tableau Postgres database, which tracks server performance meta-data. Server infraction definitions are defined in the `moniteur` database; they are meant to be editable/customizable. We are also developing a basic `moniteur` **frontend** (Django web-pages) to provide [A] read-only view access to server infraction data and [B] admin access for easier editing/configuration. 

`Moniteur` is custom code written for free, public use with no warranty.

#### Software stack
`Moniteur` is written in [Python 2.7](https://www.python.org/downloads/) and built on the [Django](https://www.djangoproject.com/) framework. It uses a MySQL database for data storage by default, but you can substitute your own RDBMS supported by Django's ORM.  

**Created by:** Peter Woyzbun  
**Maintained by:** Will Bishop, Kevin Chiang  

<br>

## Installation


1. Clone the moniteur repository locally.

### Database Setup

2. Configure your Tableau and moniteur database settings in `moniteur-settings.py`. You'll need to create a database for moniteur.

3. To create the database schema, in the moniteur directory, run ```python moniteur.py createtables```. 

4. To load the default moniteur infraction types into the database, run ```python moniteur.py loaddata```

### Admin Setup

4. To use the admin panel, you first need to create a super user. To do so, run ```python moniteur.py auth createsuperuser```, and enter the required information.

5. To start the admin server locally, run ```python moniteur.py runserver```.
