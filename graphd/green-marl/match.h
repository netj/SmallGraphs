#ifndef _SMALLGRAPH_H_
#define _SMALLGRAPH_H_

#include <list>
#include <vector>
#include <iostream>
using namespace std;

typedef long long nodeedge_id_t;
typedef long long type_t;

typedef vector<type_t> SmallGraphWalk;
typedef vector<SmallGraphWalk *> SmallGraphQuery;

class Match;
typedef vector<nodeedge_id_t> MatchPath;
typedef vector<MatchPath *> MatchPaths;
typedef list<Match *> Matches;

class Match {
    public:
        Match(SmallGraphQuery& q);
        Match(const Match& m);
        ~Match();

        Matches& extendWithNode(type_t type, nodeedge_id_t id, Matches* matches = new Matches());
        Matches& extendWithEdge(type_t type, nodeedge_id_t id, Matches* matches = new Matches());
        bool isComplete();

        void show(ostream& out = cout);

        MatchPaths* paths;

   private:
        SmallGraphQuery& query;
};

#endif // _SMALLGRAPH_H_
