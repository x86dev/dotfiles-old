#!/usr/bin/python

import ast
import codecs
import getopt
import requests
import hashlib
import json
import urllib
import sys

# pylint: disable=C0301
# pylint: disable=C0326

g_fDryRun        = True
g_cVerbosity     = 0
g_dbRatingMin    = 0.0
g_fRatingNone    = False
g_sProvider      = ""

# Configuration
g_sHost = ""
g_sUsername = ""
g_sPassword = ""

def embyCleanup():

    global g_fDryRun
    global g_cVerbosity
    global g_dbRatingMin
    global g_fRatingNone

    pw_sha1 = hashlib.sha1(g_sPassword).hexdigest()
    pw_md5  = hashlib.md5(g_sPassword).hexdigest()

    # Authenticate.
    post_url = g_sHost + "/Users/AuthenticateByName"
    post_header = {'content-type': 'application/json',
                'Authorization' : 'MediaBrowser Client="Android", Device="Generic", DeviceId="Custom", Version="1.0.0.0"'}

    post_data = {"Username": g_sUsername, "password": pw_sha1, "passwordMd5": pw_md5, "appName": "foo" }
    resp = requests.post(post_url, json=post_data, headers=post_header)

    if resp.ok:
        resp_data = resp.json()
        #print(resp_data)
        emby_server_id=resp_data[u'ServerId']
        emby_user_id=resp_data[u'SessionInfo'][u'UserId']
        emby_access_token=resp_data[u'AccessToken']
    else:
        resp.raise_for_status()

    # Construct new header containing the retrieved access token.
    get_header = {'content-type': 'application/json',
                'X-MediaBrowser-Token' : emby_access_token}

    # Retrieve all items
    get_url = g_sHost + "/Users/" + emby_user_id + "/Items?Recursive=true&IncludeItemTypes=Movie"
    resp = requests.get(get_url, headers=get_header)

    if resp.ok:
        resp_data = resp.json()
        #print(resp_data)
    else:
        resp.raise_for_status()
        return

    cItemsPurged = 0
    cItemsProc   = 0

    for movie in resp_data[u'Items']:
        movie_name = movie.get(u'Name')
        movie_rating = float(movie.get(u'CommunityRating', 0.0))
        movie_rating = round(movie_rating, 2)
        movie_imdb_id = movie.get(u'UserData').get(u'Key')

        if g_cVerbosity > 1:
            print("%s (%s): %s / %f %f" % (movie.get(u'Name'), movie.get(u'PremiereDate'), \
                                        movie.get(u'CriticRating'), movie_rating, g_dbRatingMin))

        # Don't delete any items by default.
        fDelete = False

        if g_fRatingNone is True \
        and movie_rating == 0.0:

            if g_cVerbosity:
                print("'%s': Has no rating within Emby (yet)" % (movie_name))

            # Do we want to query OMDB for a rating?
            if g_sProvider == 'omdb':
                url = "http://www.omdbapi.com/?t=" + urllib.quote(movie.get('Name'))
                resp = requests.get(url)
                if (resp.ok):
                    omdb = json.loads(resp.text)
                    if omdb.get(u'Response') == 'True':
                        movie_rating = float(omdb.get(u'imdbRating', 0.0))
                        if g_cVerbosity > 0:
                           print("\tOMDB's rating is: %f" % (movie_rating))

                    # Still no rating found?
                    if movie_rating == 0.0:
                        fDelete = True
            else:
                fDelete = True

        if  g_dbRatingMin > 0.0 \
        and movie_rating > 0.0  \
        and movie_rating < g_dbRatingMin:
            if g_cVerbosity:
                print("'%s': Has a lower rating (%f)" % (movie_name, movie_rating))
            fDelete = True

        if fDelete:
            print("'%s': Deleting ..." % (movie_name))

            # Delete item.
            if g_fDryRun is False:
                movie_id = movie.get(u'Id')
                if movie_id is not None:
                    get_url = g_sHost + "/Items/" + movie_id
                    resp = requests.delete(get_url, headers=get_header)
                    if resp.ok:
                        print("'%s': Sucessfully deleted" % (movie_name))

            cItemsPurged += 1

        cItemsProc += 1

    print("Deleted %ld / %ld items" % (cItemsPurged, cItemsProc))

def printHelp():
    print("--delete")
    print("    Deletion mode: Items *are* removed.")
    print("--help or -h")
    print("    Prints this help text.")
    print("--host <http://host:port>")
    print("    Hostname to connect to.")
    print("--password <password>")
    print("    Password to authenticate with.")
    print("--provider <type>")
    print("    Provider to use for information lookup.")
    print("    Currently only 'omdb' supported.")
    print("--rating-min <number>")
    print("    Selects items which have a lower rating than specified.")
    print("--rating-none")
    print("    Selects items which don't have a rating (yet).")
    print("--username <name>")
    print("    User name to authenticate with.")
    print("-v")
    print("    Increases logging verbosity. Can be specified multiple times.")
    print("\n")

def main():
    global g_fDryRun
    global g_cVerbosity
    global g_dbRatingMin
    global g_fRatingNone
    global g_sProvider

    global g_sHost
    global g_sUsername
    global g_sPassword

    # For output of unicode strings. Can happen with some movie titles.
    sys.stdout = codecs.getwriter('utf8')(sys.stdout)
    sys.stderr = codecs.getwriter('utf8')(sys.stderr)

    try:
        aOpts, aArgs = getopt.gnu_getopt(sys.argv[1:], "hv", \
            [ "delete", "help", "password=", "rating-min=", "rating-none", "username=", "provider=" ])
    except getopt.error, msg:
        print msg
        print "For help use --help"
        sys.exit(2)

    if len(aArgs) < 1:
        print("No host specified, e.g. http://<ip>:<port>\n")
        print("Usually Emby runs on port 8096 (http) or 8920 (https).\n\n")
        sys.exit(1)

    g_sHost = aArgs[0]

    for o, a in aOpts:
        if o in ("--delete"):
            g_fDryRun = False
        elif o in ("-h", "--help"):
            printHelp()
            sys.exit(0)
        elif o in ("--password"):
            g_sPassword = a
        elif o in ("--rating-none"):
            g_fRatingNone = True
        elif o in ("--rating-min"):
            g_dbRatingMin = float(a)
        elif o in ("--username"):
            g_sUsername = a
        elif o in ("--provider"):
            g_sProvider = a
        elif o in ("-v"):
            g_cVerbosity += 1
        else:
            assert False, "Unhandled option"

    if not g_sUsername:
        print("No username specified\n")
        sys.exit(1)

    if  g_fRatingNone is False \
    and g_dbRatingMin <= 0.0:
        print("Must specify --rating-min and/or no --rating-none\n")
        sys.exit(1)

    if g_cVerbosity:
        if  g_dbRatingMin > 0.0:        
            print("Selecting: All items with a rating < %.1f" % (g_dbRatingMin))
        if  g_fRatingNone:        
            print("Selecting: All items which don't have a rating (yet)")            

    if g_fDryRun:
        print("*** Dryrun mode -- no items changed! ***")

    print("Connecting to: %s" % (g_sHost))

    embyCleanup()

    if g_fDryRun:
        print("\n*** Dryrun mode -- no items changed! ***")

if __name__ == "__main__":
    main()
