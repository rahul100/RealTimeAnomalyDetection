import matplotlib
# Force matplotlib to not use any Xwindows backend.
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from sklearn import metrics
def create_roc_curve(algo , dataset_tag , fpr , tpr, roc_auc,col ):
        plt.title('Receiver Operating Characteristic for %s'%(dataset_tag))
        plt.plot(fpr , tpr, 'b',label='AUC for %s = %0.2f'% (algo , roc_auc), color=col)
        plt.legend(loc='lower right', prop={'size':8})
        plt.plot([0,1],[0,1],'r--')
        plt.xlim([-0.1,1.2])
        plt.ylim([-0.1,1.2])
        plt.ylabel('True Positive Rate')
        plt.xlabel('False Positive Rate')
        plt.savefig('roc_curves_for_%s.jpg' %(dataset_tag) , type='jpg')
#y = np.array([1, 1, 2, 2])
#scores = np.array([0.1, 0.4, 0.35, 0.8])

#y = np.random.randint(2, size=10000)
#scores = np.random.rand(10000)*0.1
	
#print scores
y = np.array([1, 1, 0, 0,1,0,1,0,1,0 , 1 , 0 , 1 , 0,  0 , 0 , 0 , 0, 0, 0, 0 , 0 , 1 ,1 , 1 , 0 , 1  , 1  , 0 , 1])
scores = np.array([1.0, 0.4, 0.35, 0.8 , .99 , .2 , 0.6  , 0.3 , 0.7 , 0.4 , 0.99 , 0.1 , 0.3 , .8, .9 , .9  ,.3  , 0.4 , 0.9  , 0.8  , 0.7 , 0.9 , 0.8 , 0.75 , 0.33 , 0.5 , 0.3 , 0.3 , 0.65 , 0.7 ])
fpr, tpr, thresholds = metrics.roc_curve(y, scores)
#print thresholds
auc_score=metrics.auc(fpr,tpr)
create_roc_curve("xyz" , "abc" , fpr , tpr , auc_score , 'blue')
#print auc_score
