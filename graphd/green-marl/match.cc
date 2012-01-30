#include "match.h"

Match::Match(SmallGraphQuery& q) : query(q) {
    this->paths = new MatchPaths();
    for (SmallGraphQuery::iterator it = q.begin(); it != q.end(); it++) {
        this->paths->push_back(new MatchPath());
    }
}

Match::Match(const Match& m) : query(m.query) {
    // TODO do this more efficiently?
    this->paths = new MatchPaths();
    for (MatchPaths::iterator it = m.paths->begin(); it != m.paths->end(); it++) {
        this->paths->push_back(new MatchPath(**it));
    }
}

Match::~Match() {
    for (MatchPaths::iterator it = this->paths->begin(); it != this->paths->end(); it++) {
        delete *it;
    }
    delete this->paths;
}

Matches& Match::extendWithNode(type_t type, nodeedge_id_t id, Matches* matches) {
    SmallGraphQuery& q = this->query;
    int i = 0;
    SmallGraphQuery::iterator it;
    for (it = q.begin(); it != q.end(); it++) {
        SmallGraphWalk *qpath = *it;
        unsigned int curStepIdx = this->paths->at(i)->size();
        if (curStepIdx < qpath->size()
                && qpath->at(curStepIdx) == type) {
            // TODO instead of copying m, try to create an augmented object that shares m
            Match *m = new Match(*this);
            m->paths->at(i)->push_back(id);
            matches->push_back(m);
        }
        i++;
    }
    return *matches;
}

Matches& Match::extendWithEdge(type_t type, nodeedge_id_t id, Matches* matches) {
    // TODO only remember edges?
    return this->extendWithNode(type, id, matches);
}

bool Match::isComplete() {
    MatchPaths::iterator it;
    SmallGraphQuery::iterator qit;
    for (it = this->paths->begin(), qit = this->query.begin();
            it < this->paths->end() && qit < this->query.end(); it++, qit++) {
        MatchPath *path = *it;
        SmallGraphWalk *qpath = *qit;
        if (path->size() < qpath->size())
            return false;
    }
    return true;
}

void Match::show(ostream& cout) {
    cout << "{" <<endl;
    MatchPaths::iterator it;
    for (it = this->paths->begin(); it < this->paths->end(); it++) {
        MatchPath *path = *it;
        MatchPath::iterator step = path->begin();
        cout << "\t";
        if (step < path->end())
            cout << *step;
        for (step++; step < path->end(); step++) {
            cout << " - ";
            cout << *step;
        }
        cout <<endl;
    }
    cout << "}" <<endl;
}
