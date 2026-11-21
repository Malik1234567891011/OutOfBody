import { chromium } from '/Users/malik/OutOfBody/web/node_modules/playwright/index.mjs'
const items=[
 ['s1.png','See what your vape <em>really</em> is','Your habit in packs, milligrams and dollars.'],
 ['s2.png','A daily budget that <em>shrinks</em>','Log each hit. Stay under. Step down weekly.'],
 ['s3.png','Log in <em>one tap</em>','Right from your lock screen. No unlocking.'],
 ['s4.png','Cravings <em>pass</em>','Hit SOS and breathe through it in 90 seconds.'],
 ['s5.png','Nicotine-free <em>by a date</em>','A step-down plan that adapts to your week.'],
]
const b=await chromium.launch({channel:'chrome'}); const p=await b.newPage({viewport:{width:1320,height:2868}})
for(const [i,[img,h,s]] of items.entries()){ await p.goto('file:///Users/malik/OutOfBody/store/frame.html?'+new URLSearchParams({h,s,i:img})); await p.waitForTimeout(500); await p.screenshot({path:`/Users/malik/OutOfBody/store/appstore_${i+1}.png`}) }
await b.close()
