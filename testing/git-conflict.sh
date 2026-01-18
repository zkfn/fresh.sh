mkdir git-conflict
cd git-conflict

git init

echo "line from main" > conflict.txt

git add conflict.txt
git commit -m "initial commit on main"

git checkout -b feature
echo "line from feature branch" > conflict.txt
git commit -am "change from feature"

git checkout main
echo "line from main branch" > conflict.txt
git commit -am "change from main"

git merge feature

cd ..
